-- Owner rental actions as database functions (Person A).
-- Run AFTER 20261105000000_create_schema.sql.
--
-- The app calls these with supabase.rpc(...). Every rule is checked here on
-- the server, so even a changed app can't start a cancelled booking, start
-- one twice, or record a payment for someone else.
--
-- Only ADDS functions. No table, column, policy or trigger is changed.
-- Not included yet (waiting for the group's late-charge decision):
-- ending a rental, late charges and late payments.

-- ===============================================================
-- 1. FIND A BOOKING (O3b Scan booking)
--    p_value = the QR content (rentals.qr_token, 64 characters)
--           or the booking code typed by the owner (8 characters).
--    Returns the booking (0 or 1 row). The app decides what to show
--    from its status (start it / "already started" / "cancelled").
-- ===============================================================
CREATE OR REPLACE FUNCTION public.owner_find_booking(p_value text)
RETURNS SETOF rentals
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v text := trim(coalesce(p_value, ''));
BEGIN
    IF NOT public.is_owner() THEN
        RAISE EXCEPTION 'Only the shop owner can do this.';
    END IF;

    RETURN QUERY
        SELECT * FROM rentals r
        WHERE r.qr_token = v
           OR r.booking_code = upper(v)
        LIMIT 1;
END;
$$;

-- ===============================================================
-- 2. START A RENTAL (O5 Start rental)
--    p_payment_method: only for a booking still 'pending_payment'
--    (customer pays at the counter): 'Cash' | 'TnG' | 'Bank QR' | 'Card'.
--    Leave it NULL for bookings already paid ('ready' / 'checked_in').
--
--    In one step:
--      - records the counter payment (if any) in payments
--      - the timer starts now and runs for the booked blocks
--      - booking -> 'active', vehicle -> 'Rented'
-- ===============================================================
CREATE OR REPLACE FUNCTION public.owner_start_rental(
    p_rental_id      text,
    p_payment_method text DEFAULT NULL
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

    -- FOR UPDATE: if two phones tap Start at the same time, one waits.
    SELECT * INTO r FROM rentals WHERE id = p_rental_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;

    IF r.status IN ('active', 'completed') THEN
        RAISE EXCEPTION 'This booking has already started.';
    ELSIF r.status IN ('cancelled', 'expired') THEN
        RAISE EXCEPTION 'This booking is cancelled or expired.';
    END IF;
    -- Left: 'pending_payment', 'ready', 'checked_in'.

    IF r.status = 'pending_payment' THEN
        IF p_payment_method IS NULL THEN
            RAISE EXCEPTION 'Confirm the payment before starting.';
        END IF;
        IF p_payment_method NOT IN ('Cash', 'TnG', 'Bank QR', 'Card') THEN
            RAISE EXCEPTION 'Unknown payment method.';
        END IF;
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

    -- The timer starts at handover, so the customer gets the full time.
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
-- 3. VEHICLE IS BACK (O3 "Returned" button)
--    Saves the return time and stops late auto-charging.
--    The rental stays 'active' until the owner checks it on End rental.
-- ===============================================================
CREATE OR REPLACE FUNCTION public.owner_mark_returned(p_rental_id text)
RETURNS rentals
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    r rentals%ROWTYPE;
BEGIN
    IF NOT public.is_owner() THEN
        RAISE EXCEPTION 'Only the shop owner can do this.';
    END IF;

    SELECT * INTO r FROM rentals WHERE id = p_rental_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;
    IF r.status <> 'active' THEN
        RAISE EXCEPTION 'This rental has not started.';
    END IF;
    IF r.actual_end_time IS NOT NULL THEN
        RAISE EXCEPTION 'This vehicle is already marked as returned.';
    END IF;

    UPDATE rentals
       SET actual_end_time     = now(),
           auto_charge_stopped = true
     WHERE id = r.id
    RETURNING * INTO r;

    RETURN r;
END;
$$;

-- ===============================================================
-- 4. WHO CAN CALL THEM: signed-in users only (each function also
--    checks is_owner(), so a customer gets "Only the shop owner…").
-- ===============================================================
REVOKE ALL ON FUNCTION public.owner_find_booking(text)        FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.owner_start_rental(text, text)  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.owner_mark_returned(text)       FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_find_booking(text)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_start_rental(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_mark_returned(text)      TO authenticated;
