-- Owner rental screens (Person A), last database part:
-- condition checks, End rental (late charge, refund / waive, payment) and receipt access.
-- Run AFTER 20261118000000_owner_rental_functions.sql.
--
-- Changes only Person A's own function owner_start_rental (adds the pickup
-- condition) and adds new things. No teammate's table, column or function changes.

-- ===============================================================
-- 1. READ RULES (RLS) for payments and vehicle_condition_checks
--    Both tables had no rules, so nobody could use them from the app.
--    Writing still goes only through the owner functions below.
--    ENABLE is safe to run even if RLS is already on.
-- ===============================================================
ALTER TABLE payments                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_condition_checks ENABLE ROW LEVEL SECURITY;

-- Owner: every payment (O6c receipt, O11 payments).
-- Customer: only payments of their own rentals (their receipt).
CREATE POLICY payments_select_own_or_owner ON payments
    FOR SELECT TO authenticated
    USING (public.is_owner()
           OR EXISTS (SELECT 1 FROM rentals r
                      WHERE r.id = payments.rental_id
                        AND r.customer_id = (SELECT auth.uid())));

CREATE POLICY condition_checks_owner_select ON vehicle_condition_checks
    FOR SELECT TO authenticated
    USING (public.is_owner());

-- ===============================================================
-- 2. START RENTAL + PICKUP CONDITION (O5)
--    Same as before (ADP-140), plus p_condition: Good / Minor issue / Damaged,
--    saved in vehicle_condition_checks (stage 'pickup').
--    The old 2-argument version is dropped first so the app can't call the
--    wrong one. Nothing calls it yet.
-- ===============================================================
DROP FUNCTION IF EXISTS public.owner_start_rental(text, text);

CREATE OR REPLACE FUNCTION public.owner_start_rental(
    p_rental_id      text,
    p_payment_method text DEFAULT NULL,
    p_condition      text DEFAULT 'Good'
)
RETURNS rentals
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    r     rentals%ROWTYPE;
    v     vehicles%ROWTYPE;
    t_now timestamptz := now();
    t_end timestamptz;
BEGIN
    IF NOT public.is_owner() THEN
        RAISE EXCEPTION 'Only the shop owner can do this.';
    END IF;

    SELECT * INTO r FROM rentals WHERE id = p_rental_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;

    IF r.status IN ('active', 'completed') THEN
        RAISE EXCEPTION 'This booking has already started.';
    ELSIF r.status IN ('cancelled', 'expired') THEN
        RAISE EXCEPTION 'This booking is cancelled or expired.';
    END IF;

    IF r.status = 'pending_payment' THEN
        IF p_payment_method IS NULL THEN
            RAISE EXCEPTION 'Confirm the payment before starting.';
        END IF;
        IF p_payment_method NOT IN ('Cash', 'TnG', 'Bank QR', 'Card') THEN
            RAISE EXCEPTION 'Unknown payment method.';
        END IF;
    END IF;

    IF coalesce(p_condition, 'Good') NOT IN ('Good', 'Minor issue', 'Damaged') THEN
        RAISE EXCEPTION 'Unknown vehicle condition.';
    END IF;
    IF p_condition = 'Damaged' THEN
        RAISE EXCEPTION 'This vehicle is damaged. Choose another vehicle.';
    END IF;

    SELECT * INTO v FROM vehicles WHERE id = r.vehicle_id FOR UPDATE;
    IF v.status = 'Maintenance' OR NOT v.is_active THEN
        RAISE EXCEPTION 'This vehicle is under maintenance.';
    END IF;
    IF EXISTS (SELECT 1 FROM rentals
               WHERE vehicle_id = r.vehicle_id AND status = 'active'
                 AND id <> r.id) THEN
        RAISE EXCEPTION 'This vehicle is still out on another rental.';
    END IF;

    t_end := t_now + r.blocks_booked * interval '20 minutes';
    IF EXISTS (SELECT 1 FROM rentals
               WHERE vehicle_id = r.vehicle_id AND id <> r.id
                 AND status IN ('ready', 'checked_in')
                 AND tstzrange(scheduled_start_time, scheduled_end_time)
                     && tstzrange(t_now, t_end)) THEN
        RAISE EXCEPTION 'This vehicle is booked by another customer before this rental would end.';
    END IF;

    IF r.status = 'pending_payment' THEN
        INSERT INTO payments (rental_id, amount, payment_method, payment_type,
                              status, is_auto, confirmed_by, paid_at)
        VALUES (r.id, r.total_amount, p_payment_method, 'upfront',
                'completed', false, auth.uid(), t_now);
    END IF;

    INSERT INTO vehicle_condition_checks (rental_id, stage, condition)
    VALUES (r.id, 'pickup', coalesce(p_condition, 'Good'));

    UPDATE rentals
       SET status               = 'active',
           actual_start_time    = t_now,
           scheduled_start_time = t_now,
           scheduled_end_time   = t_end,
           original_end_time    = t_end
     WHERE id = r.id
    RETURNING * INTO r;

    UPDATE vehicles SET status = 'Rented' WHERE id = r.vehicle_id;

    RETURN r;
END;
$$;

-- ===============================================================
-- 3. END RENTAL (O6, with O6b payment)
--
--    p_return_time   when the vehicle came back. NULL = the time saved by
--                    "Returned" on O3, or now. The owner may correct it on O6.
--    p_condition     'Good' | 'Minor issue' | 'Damaged'
--    p_issue_note    required unless Good
--    p_issue_photo   storage path of the issue photo (report-photos bucket), optional
--    p_waive         true = owner forgives the late charge
--    p_payment_method  'Card' | 'Cash' | 'TnG' | 'Bank QR' for late blocks that
--                    were not auto-charged (walk-ins, or a failed auto-charge)
--
--    LATE CHARGE RULE (same as the app, rental.dart):
--      free for grace_minutes_at_booking (5), then each started 20 minutes
--      = 1 block, at most shop_settings.auto_charge_limit (3) blocks.
--      Price per late block = the vehicle's price saved on the booking.
--
--    Returns the amounts so O6c can show the receipt.
-- ===============================================================
CREATE OR REPLACE FUNCTION public.owner_end_rental(
    p_rental_id      text,
    p_return_time    timestamptz DEFAULT NULL,
    p_condition      text        DEFAULT 'Good',
    p_issue_note     text        DEFAULT NULL,
    p_issue_photo    text        DEFAULT NULL,
    p_waive          boolean     DEFAULT false,
    p_payment_method text        DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    r              rentals%ROWTYPE;
    max_blocks     integer;
    late_price     numeric;
    t_return       timestamptz;
    late_min       integer;
    late_blocks    integer := 0;
    owed_blocks    integer;
    charged_blocks integer;
    refund_blocks  integer;
    extra_blocks   integer;
    auto_pay       payments%ROWTYPE;
    note           text := nullif(trim(coalesce(p_issue_note, '')), '');
    cond           text := coalesce(p_condition, 'Good');
BEGIN
    IF NOT public.is_owner() THEN
        RAISE EXCEPTION 'Only the shop owner can do this.';
    END IF;

    SELECT * INTO r FROM rentals WHERE id = p_rental_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;
    IF r.status <> 'active' THEN
        RAISE EXCEPTION 'This rental is not active.';
    END IF;

    -- ---- return time ----
    t_return := coalesce(p_return_time, r.actual_end_time, now());
    IF t_return < r.actual_start_time THEN
        RAISE EXCEPTION 'The return time is before the rental started.';
    END IF;
    IF t_return > now() + interval '1 minute' THEN
        RAISE EXCEPTION 'The return time is in the future.';
    END IF;

    -- ---- condition ----
    IF cond NOT IN ('Good', 'Minor issue', 'Damaged') THEN
        RAISE EXCEPTION 'Unknown vehicle condition.';
    END IF;
    IF cond <> 'Good' AND note IS NULL THEN
        RAISE EXCEPTION 'Describe the issue.';
    END IF;

    -- ---- late charge ----
    SELECT auto_charge_limit INTO max_blocks FROM shop_settings WHERE id = 1;
    late_price := r.rate_per_block_at_booking;   -- << the one line to change if the group picks late_rate_at_booking

    late_min := floor(extract(epoch FROM (t_return - r.scheduled_end_time)) / 60);
    IF late_min > r.grace_minutes_at_booking THEN
        late_blocks := least(ceil((late_min - r.grace_minutes_at_booking) / 20.0)::integer,
                             coalesce(max_blocks, 3));
    END IF;

    owed_blocks    := CASE WHEN p_waive THEN 0 ELSE late_blocks END;
    charged_blocks := CASE WHEN r.is_walk_in THEN 0 ELSE r.late_blocks_charged END;
    refund_blocks  := greatest(0, charged_blocks - owed_blocks);
    extra_blocks   := greatest(0, owed_blocks - charged_blocks);

    -- Late blocks not auto-charged: collected now at the counter (O6b).
    IF extra_blocks > 0 THEN
        IF p_payment_method IS NULL THEN
            RAISE EXCEPTION 'Collect the late charge first.';
        END IF;
        IF p_payment_method NOT IN ('Cash', 'TnG', 'Bank QR', 'Card') THEN
            RAISE EXCEPTION 'Unknown payment method.';
        END IF;
        INSERT INTO payments (rental_id, amount, payment_method, payment_type,
                              status, is_auto, confirmed_by, paid_at)
        VALUES (r.id, extra_blocks * late_price, p_payment_method, 'late_block',
                'completed', false, auth.uid(), now());
    END IF;

    -- Auto-charged too much (waived, or return time corrected): record the
    -- refund. The card refund itself is done by the payment gateway later.
    IF refund_blocks > 0 THEN
        SELECT * INTO auto_pay FROM payments
         WHERE rental_id = r.id AND payment_type = 'late_block'
           AND is_auto AND status = 'completed'
         ORDER BY created_at DESC LIMIT 1;
        INSERT INTO payments (rental_id, amount, payment_method, payment_type,
                              status, is_auto, confirmed_by, paid_at, refund_of)
        VALUES (r.id, refund_blocks * late_price,
                coalesce(auto_pay.payment_method, 'Card'), 'late_block',
                'refunded', false, auth.uid(), now(), auto_pay.id);
    END IF;

    -- ---- condition at return + issue for the maintenance list ----
    INSERT INTO vehicle_condition_checks (rental_id, stage, condition, notes, photo_url)
    VALUES (r.id, 'return', cond, note, p_issue_photo);

    IF cond <> 'Good' THEN
        INSERT INTO maintenance_logs (vehicle_id, reported_by, rental_id, log_type,
                                      issue_description, status, photo_path)
        VALUES (r.vehicle_id, auth.uid(), r.id, 'service',
                'Found at return (' || cond || '): ' || note, 'pending', p_issue_photo);
    END IF;

    -- ---- finish ----
    UPDATE rentals
       SET status              = 'completed',
           actual_end_time     = t_return,
           auto_charge_stopped = true
     WHERE id = r.id;

    -- Damaged -> out of service until fixed. Ride time is added to the vehicle.
    UPDATE vehicles
       SET status           = CASE WHEN cond = 'Damaged' THEN 'Maintenance' ELSE 'Available' END,
           total_ride_hours = total_ride_hours
                              + greatest(0, extract(epoch FROM (t_return - r.actual_start_time)) / 3600.0),
           reported_issues  = reported_issues + CASE WHEN cond <> 'Good' THEN 1 ELSE 0 END
     WHERE id = r.vehicle_id;

    RETURN json_build_object(
        'rental_id',        r.id,
        'return_time',      t_return,
        'late_minutes',     greatest(late_min, 0),
        'late_blocks',      late_blocks,
        'late_price',       late_price,
        'waived',           p_waive,
        'charged_blocks',   charged_blocks,
        'collected_amount', extra_blocks * late_price,
        'refund_amount',    refund_blocks * late_price,
        'rental_amount',    r.total_amount,
        'condition',        cond
    );
END;
$$;

-- ===============================================================
-- 4. WHO CAN CALL THEM
-- ===============================================================
REVOKE ALL ON FUNCTION public.owner_start_rental(text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.owner_end_rental(text, timestamptz, text, text, text, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_start_rental(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_end_rental(text, timestamptz, text, text, text, boolean, text) TO authenticated;
