-- Owner rental functions, update (Person A):
--   1. NEW  owner_confirm_payment: counter payment for an app booking
--   2. owner_start_rental: blocks "Not in use" vehicles and locks the
--      vehicle's late price (vehicles.late_rate_per_block) into the booking
--   3. owner_end_rental: charges that locked late price (late_rate_at_booking)
-- Run AFTER 20261120000000_late_charge_no_limit.sql.
--
-- Only Person A's own functions change; no table or column changes.
-- Late charge rule is unchanged: 5 min grace, every started 20 min = 1 block,
-- no upper limit.

-- ===============================================================
-- 1. CONFIRM COUNTER PAYMENT (Start rental screen, "Confirm payment")
--    The customer booked in the app and pays at the counter.
--    Saves the payment and moves the booking: pending_payment -> ready.
--    p_method: 'Cash' | 'TnG' | 'Bank QR' | 'Card'
-- ===============================================================
CREATE OR REPLACE FUNCTION public.owner_confirm_payment(
    p_rental_id text,
    p_method    text
)
RETURNS rentals
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    r rentals%ROWTYPE;
BEGIN
    IF NOT public.is_owner() THEN
        RAISE EXCEPTION 'Only the shop owner can do this.';
    END IF;

    -- FOR UPDATE: two taps at the same time can't record two payments.
    SELECT * INTO r FROM rentals WHERE id = p_rental_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;
    IF r.status <> 'pending_payment' THEN
        RAISE EXCEPTION 'This booking is already paid or no longer waiting for payment.';
    END IF;
    IF p_method IS NULL OR p_method NOT IN ('Cash', 'TnG', 'Bank QR', 'Card') THEN
        RAISE EXCEPTION 'Unknown payment method.';
    END IF;

    INSERT INTO payments (rental_id, amount, payment_method, payment_type,
                          status, is_auto, confirmed_by, paid_at)
    VALUES (r.id, r.total_amount, p_method, 'upfront',
            'completed', false, auth.uid(), now());

    UPDATE rentals SET status = 'ready' WHERE id = r.id
    RETURNING * INTO r;

    RETURN r;
END;
$$;

-- ===============================================================
-- 2. START RENTAL: same as before, plus "Not in use" check and
--    the vehicle's late price locked into the booking.
-- ===============================================================
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
    IF v.status = 'Maintenance' THEN
        RAISE EXCEPTION 'This vehicle is under maintenance.';
    END IF;
    IF v.status = 'Not in use' OR NOT v.is_active THEN
        RAISE EXCEPTION 'This vehicle is not in use.';
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

    -- Lock this vehicle's late price into the booking at handover.
    -- End rental and the customer's screens both read late_rate_at_booking,
    -- so owner and customer always show the same late charge.
    UPDATE rentals
       SET status               = 'active',
           late_rate_at_booking = coalesce(v.late_rate_per_block, v.rate_per_block),
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
-- 3. END RENTAL: same as before, but late blocks are charged at
--    late_rate_at_booking (the vehicle's late price at handover).
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
    -- The vehicle's late price, locked in by owner_start_rental.
    -- Older rentals started before this change may still hold the shop rate
    -- (0 if never set): then fall back to the vehicle's normal price.
    late_price := CASE WHEN r.late_rate_at_booking > 0
                       THEN r.late_rate_at_booking
                       ELSE r.rate_per_block_at_booking END;

    late_min := floor(extract(epoch FROM (t_return - r.scheduled_end_time)) / 60);
    IF late_min > r.grace_minutes_at_booking THEN
        -- No upper limit: one more block for every started 20 minutes.
        late_blocks := ceil((late_min - r.grace_minutes_at_booking) / 20.0)::integer;
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
-- 4. WHO CAN CALL IT (start / end keep their existing permissions)
-- ===============================================================
REVOKE ALL ON FUNCTION public.owner_confirm_payment(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_confirm_payment(text, text) TO authenticated;
