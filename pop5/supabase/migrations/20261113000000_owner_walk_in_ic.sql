-- Owner rental screens (Person A): walk-in IC photos + IC view log.
-- Run AFTER 20261105000000_create_schema.sql.
--
-- Only ADDS things. It does not change any existing column, policy, trigger
-- or the customer IC upload rules, so no other screen is affected.
--
-- The "Returned" step on O3 needs no change: it uses the existing
--   rentals.actual_end_time      = time the vehicle came back
--   rentals.auto_charge_stopped  = stop auto-charging late blocks

-- ===============================================================
-- 1. WALK-IN IC PHOTOS (O4): where the front/back photos are stored.
--    Walk-ins have no account, so the photos belong to the rental.
--    Files go in the private ic-documents bucket under
--    walk-in/<rental id>/front.jpg and walk-in/<rental id>/back.jpg
--    Both columns are optional (the IC photo is optional for walk-ins).
-- ===============================================================
ALTER TABLE rentals ADD COLUMN IF NOT EXISTS walk_in_ic_front_path varchar(255);
ALTER TABLE rentals ADD COLUMN IF NOT EXISTS walk_in_ic_back_path  varchar(255);

-- Only the owner may set these paths. A customer booking (C5) always has
-- them cleared, so a customer can't point a booking at someone's IC.
-- (A separate trigger, so the existing rentals_before_insert is untouched.)
CREATE OR REPLACE FUNCTION public.rentals_clear_walk_in_ic()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF auth.uid() IS NOT NULL AND NOT public.is_owner() THEN
        NEW.walk_in_ic_front_path := NULL;
        NEW.walk_in_ic_back_path  := NULL;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_rentals_clear_walk_in_ic
    BEFORE INSERT ON rentals
    FOR EACH ROW EXECUTE FUNCTION public.rentals_clear_walk_in_ic();

-- The owner may upload / replace files in the walk-in/ folder only.
-- (Reading is already allowed for the owner by ic_read_own_or_owner.)
CREATE POLICY ic_owner_upload_walk_in ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'ic-documents'
                AND (storage.foldername(name))[1] = 'walk-in'
                AND public.is_owner());

CREATE POLICY ic_owner_update_walk_in ON storage.objects
    FOR UPDATE TO authenticated
    USING      (bucket_id = 'ic-documents'
                AND (storage.foldername(name))[1] = 'walk-in'
                AND public.is_owner())
    WITH CHECK (bucket_id = 'ic-documents'
                AND (storage.foldername(name))[1] = 'walk-in'
                AND public.is_owner());

-- ===============================================================
-- 2. IC VIEW LOG (O3c / O5 "View IC"): who looked at an IC and when.
--    Personal data, so every view is recorded. Rows can't be edited
--    or deleted from the app (no UPDATE / DELETE policy).
-- ===============================================================
CREATE TABLE IF NOT EXISTS ic_access_log (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    viewed_by    uuid        NOT NULL DEFAULT auth.uid()
                             REFERENCES public.users (id) ON DELETE CASCADE,
    customer_id  uuid        REFERENCES public.users (id) ON DELETE SET NULL, -- app customer
    rental_id    text        REFERENCES public.rentals (id) ON DELETE SET NULL, -- walk-in / booking
    viewed_at    timestamptz NOT NULL DEFAULT now(),
    CHECK (customer_id IS NOT NULL OR rental_id IS NOT NULL)
);

ALTER TABLE ic_access_log ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.ic_access_log FROM anon, authenticated;
GRANT SELECT, INSERT ON public.ic_access_log TO authenticated;

-- Only the owner can add a log row, and only as themselves.
CREATE POLICY ic_access_log_owner_insert ON ic_access_log
    FOR INSERT TO authenticated
    WITH CHECK (public.is_owner() AND viewed_by = (SELECT auth.uid()));

-- Only the owner can read the log.
CREATE POLICY ic_access_log_owner_select ON ic_access_log
    FOR SELECT TO authenticated
    USING (public.is_owner());
