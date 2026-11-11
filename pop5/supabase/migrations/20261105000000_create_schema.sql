-- Moves the app to Supabase Auth and lets the Flutter app talk to the database
-- safely (RLS policies). Run AFTER your initial schema migration.
-- (The Supabase CLI wraps migrations in a transaction, so no BEGIN/COMMIT here.)
--
-- Before running, in Supabase: Authentication -> Providers -> Email -> turn OFF
-- "Confirm email" while developing (sign-up must return a session to upload the IC).

-- ===============================================================
-- 1. USERS: tied to Supabase Auth (auth.users holds the password)
-- ===============================================================
ALTER TABLE users DROP COLUMN IF EXISTS password_hash;
ALTER TABLE users ALTER COLUMN id DROP DEFAULT;

-- NOT VALID: old test rows that are not in auth.users do not block the migration;
-- every new row must match an auth user.
ALTER TABLE users
    ADD CONSTRAINT users_id_fkey
    FOREIGN KEY (id) REFERENCES auth.users (id) ON DELETE CASCADE NOT VALID;

ALTER TABLE users ADD COLUMN IF NOT EXISTS ic_front_path        varchar(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS ic_back_path         varchar(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS accepted_ic_storage  boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS accepted_terms       boolean NOT NULL DEFAULT false;

-- ===============================================================
-- 2. HELPER: is the current user the shop owner?
-- ===============================================================
CREATE OR REPLACE FUNCTION public.is_owner()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'owner');
$$;

-- ===============================================================
-- 3. AUTO-CREATE the users row when someone signs up
--    role is NEVER taken from sign-up data (users can edit that); it stays 'customer'.
--    Make an owner by changing users.role in the Table Editor.
-- ===============================================================
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    INSERT INTO public.users (id, full_name, username, email, phone)
    VALUES (
        NEW.id,
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
                 NULLIF(split_part(COALESCE(NEW.email, ''), '@', 1), ''),
                 'Customer'),
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'username', ''),
                 'user_' || substr(replace(NEW.id::text, '-', ''), 1, 8)),
        COALESCE(NEW.email, NEW.id::text || '@no-email.invalid'),
        NULLIF(NEW.raw_user_meta_data->>'phone', '')
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- ===============================================================
-- 4. FUNCTIONS the login / sign-up screens call before the user is signed in
--    Trade-off: they let anyone test whether a phone number / username exists.
-- ===============================================================
CREATE OR REPLACE FUNCTION public.get_email_by_phone(p_phone text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT email FROM public.users WHERE phone = p_phone LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.signup_conflict(p_username text, p_phone text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT CASE
        WHEN EXISTS (SELECT 1 FROM public.users WHERE lower(username) = lower(p_username)) THEN 'username'
        WHEN EXISTS (SELECT 1 FROM public.users WHERE phone = p_phone) THEN 'phone'
        ELSE NULL
    END;
$$;

GRANT EXECUTE ON FUNCTION public.get_email_by_phone(text)        TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.signup_conflict(text, text)     TO anon, authenticated;

-- ===============================================================
-- 5. USERS: row + column security
--    RLS cannot limit columns, so column privileges stop a customer
--    from changing their own role, email or id.
-- ===============================================================
REVOKE ALL ON public.users FROM anon, authenticated;
GRANT SELECT ON public.users TO authenticated;
GRANT UPDATE (full_name, username, phone, ic_front_path, ic_back_path,
              accepted_ic_storage, accepted_terms, fcm_token)
    ON public.users TO authenticated;

CREATE POLICY users_select_own_or_owner ON users
    FOR SELECT TO authenticated
    USING (id = (SELECT auth.uid()) OR public.is_owner());

CREATE POLICY users_update_own ON users
    FOR UPDATE TO authenticated
    USING (id = (SELECT auth.uid()))
    WITH CHECK (id = (SELECT auth.uid()));

-- ===============================================================
-- 6. VEHICLES (C3 / C4): customers can read active vehicles; only the owner edits
-- ===============================================================
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS photo_url varchar(500);

CREATE POLICY vehicles_select ON vehicles
    FOR SELECT TO authenticated
    USING (is_active OR public.is_owner());

CREATE POLICY vehicles_owner_write ON vehicles
    FOR ALL TO authenticated
    USING (public.is_owner()) WITH CHECK (public.is_owner());

-- ===============================================================
-- 7. SHOP_SETTINGS: customers can read the rules (grace minutes, late rate) shown on C5
-- ===============================================================
CREATE POLICY shop_settings_select ON shop_settings
    FOR SELECT TO authenticated USING (true);

CREATE POLICY shop_settings_owner_update ON shop_settings
    FOR UPDATE TO authenticated
    USING (public.is_owner()) WITH CHECK (public.is_owner());

-- ===============================================================
-- 8. NOTIFICATIONS: own rows only; users may only change read_at
-- ===============================================================
REVOKE UPDATE ON public.notifications FROM authenticated;
GRANT UPDATE (read_at) ON public.notifications TO authenticated;

CREATE POLICY notifications_select_own ON notifications
    FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

CREATE POLICY notifications_update_own ON notifications
    FOR UPDATE TO authenticated
    USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));

-- ===============================================================
-- 9. RENTALS (C5): the app sends only vehicle_id, scheduled_start_time and blocks_booked.
--    A trigger fills in everything else so a customer cannot change the price.
-- ===============================================================
CREATE SEQUENCE IF NOT EXISTS rental_id_seq START 10000;
GRANT USAGE ON SEQUENCE rental_id_seq TO authenticated;

ALTER TABLE rentals ALTER COLUMN id           SET DEFAULT ('RNT-' || nextval('rental_id_seq')::text);
ALTER TABLE rentals ALTER COLUMN booking_code SET DEFAULT upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
ALTER TABLE rentals ALTER COLUMN qr_token     SET DEFAULT replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');

CREATE OR REPLACE FUNCTION public.rentals_before_insert()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v vehicles%ROWTYPE;
    s shop_settings%ROWTYPE;
BEGIN
    -- Direct database connection / service role (the Node.js backend): trust the caller.
    IF auth.uid() IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT * INTO v FROM vehicles WHERE id = NEW.vehicle_id AND is_active;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vehicle not found.';
    END IF;
    IF v.status <> 'Available' THEN
        RAISE EXCEPTION 'This vehicle is not available.';
    END IF;
    IF NEW.blocks_booked IS NULL OR NEW.blocks_booked NOT BETWEEN 1 AND 24 THEN
        RAISE EXCEPTION 'Choose between 20 minutes and 8 hours.';
    END IF;
    IF NEW.scheduled_start_time IS NULL OR NEW.scheduled_start_time < now() - interval '5 minutes' THEN
        RAISE EXCEPTION 'The start time is in the past.';
    END IF;

    SELECT * INTO s FROM shop_settings WHERE id = 1;

    IF NOT public.is_owner() THEN
        NEW.customer_id   := auth.uid();
        NEW.is_walk_in    := false;
        NEW.walk_in_name  := NULL;
        NEW.walk_in_phone := NULL;
        NEW.deposit_note  := NULL;
    END IF;

    NEW.status                    := 'pending_payment';
    NEW.actual_start_time         := NULL;
    NEW.actual_end_time           := NULL;
    NEW.late_blocks_charged       := 0;
    NEW.auto_charge_stopped       := false;
    NEW.distance_km               := 0;
    NEW.scheduled_end_time        := NEW.scheduled_start_time + NEW.blocks_booked * interval '20 minutes';
    NEW.original_end_time         := NEW.scheduled_end_time;
    NEW.rate_per_block_at_booking := v.rate_per_block;
    NEW.grace_minutes_at_booking  := s.grace_minutes;
    NEW.late_rate_at_booking      := s.late_rate;
    NEW.total_amount              := NEW.blocks_booked * v.rate_per_block;

    IF EXISTS (
        SELECT 1 FROM rentals r
        WHERE r.vehicle_id = NEW.vehicle_id
          AND r.status IN ('ready', 'checked_in', 'active')
          AND tstzrange(r.scheduled_start_time, r.scheduled_end_time)
              && tstzrange(NEW.scheduled_start_time, NEW.scheduled_end_time)
    ) THEN
        RAISE EXCEPTION 'This vehicle is already booked for that time.';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_rentals_before_insert
    BEFORE INSERT ON rentals
    FOR EACH ROW EXECUTE FUNCTION public.rentals_before_insert();

CREATE POLICY rentals_select_own_or_owner ON rentals
    FOR SELECT TO authenticated
    USING (customer_id = (SELECT auth.uid()) OR public.is_owner());

CREATE POLICY rentals_insert ON rentals
    FOR INSERT TO authenticated
    WITH CHECK (customer_id = (SELECT auth.uid()) OR public.is_owner());

CREATE POLICY rentals_owner_update ON rentals
    FOR UPDATE TO authenticated
    USING (public.is_owner()) WITH CHECK (public.is_owner());

-- ===============================================================
-- 10. IC PHOTOS: private storage bucket (C2b)
-- ===============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('ic-documents', 'ic-documents', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY ic_upload_own_folder ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'ic-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY ic_update_own_folder ON storage.objects
    FOR UPDATE TO authenticated
    USING      (bucket_id = 'ic-documents' AND (storage.foldername(name))[1] = auth.uid()::text)
    WITH CHECK (bucket_id = 'ic-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY ic_read_own_or_owner ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'ic-documents'
           AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_owner()));
