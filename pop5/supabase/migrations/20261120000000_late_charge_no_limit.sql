-- Late charge: remove the 3-block maximum (Person A).
-- Run AFTER 20261118010000_owner_end_rental.sql.
--
-- Rule now: free for grace_minutes_at_booking (5), then every started
-- 20 minutes = 1 block, with NO upper limit, until the vehicle is back.
-- Price per late block = the vehicle's price saved on the booking.
--
-- Replaces only owner_end_rental (same name and inputs, so the app call and
-- the permissions stay the same). shop_settings.auto_charge_limit is kept
-- but no longer used by this function.

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
    late_price := r.rate_per_block_at_booking;   -- << the one line to change if the group picks late_rate_at_booking

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
