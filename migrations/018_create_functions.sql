-- Migration 018: Create Stored Procedures & Functions
-- Description: Business logic functions for trust scores, matching, booking, and payments
-- Dependencies: All table migrations

-- Calculate and update client trust score
CREATE OR REPLACE FUNCTION calculate_client_trust_score(p_client_id UUID)
RETURNS DECIMAL(3,2) AS $$
DECLARE
    v_score DECIMAL(3,2);
    v_verification_score DECIMAL(3,2);
    v_payment_score DECIMAL(3,2);
    v_communication_score DECIMAL(3,2);
    v_cancellation_penalty DECIMAL(3,2);
    v_dispute_penalty DECIMAL(3,2);
BEGIN
    SELECT 
        CASE 
            WHEN phone_verified AND payment_method_verified AND verification_status = 'verified' THEN 10.0
            WHEN phone_verified AND payment_method_verified THEN 7.0
            WHEN phone_verified THEN 4.0
            ELSE 0.0
        END INTO v_verification_score
    FROM client_profiles WHERE id = p_client_id;
    
    SELECT 
        CASE 
            WHEN avg_payment_time_hours <= 1 THEN 10.0
            WHEN avg_payment_time_hours <= 4 THEN 8.0
            WHEN avg_payment_time_hours <= 12 THEN 6.0
            WHEN avg_payment_time_hours <= 24 THEN 4.0
            ELSE 2.0
        END INTO v_payment_score
    FROM client_profiles WHERE id = p_client_id;
    
    SELECT COALESCE(AVG(aspect_score), 5.0) INTO v_communication_score
    FROM ratings r,
    jsonb_each_text(r.aspects) AS aspect(key, value),
    LATERAL (SELECT value::DECIMAL AS aspect_score WHERE key = 'communication') sub
    WHERE r.rated_user_id IN (
        SELECT user_id FROM client_profiles WHERE id = p_client_id
    );
    
    SELECT LEAST(cancellation_rate * 20, 5.0) INTO v_cancellation_penalty
    FROM client_profiles WHERE id = p_client_id;
    
    SELECT LEAST(dispute_rate * 30, 5.0) INTO v_dispute_penalty
    FROM client_profiles WHERE id = p_client_id;
    
    v_score := (v_verification_score * 0.3 + 
                v_payment_score * 0.3 + 
                v_communication_score * 0.2 + 
                (10.0 - v_cancellation_penalty) * 0.1 +
                (10.0 - v_dispute_penalty) * 0.1);
    
    UPDATE client_trust_scores 
    SET overall_score = GREATEST(0.0, LEAST(10.0, v_score)),
        verification_score = v_verification_score,
        payment_reliability = v_payment_score,
        communication_score = v_communication_score,
        cancellation_penalty = v_cancellation_penalty,
        dispute_penalty = v_dispute_penalty,
        last_calculated_at = NOW(),
        updated_at = NOW()
    WHERE client_id = p_client_id;
    
    UPDATE client_profiles 
    SET trust_score = v_score,
        trust_level = CASE 
            WHEN v_score >= 8.0 THEN 'trusted'::trust_level
            WHEN v_score >= 5.0 THEN 'standard'::trust_level
            WHEN v_score >= 3.0 THEN 'caution'::trust_level
            ELSE 'high_risk'::trust_level
        END,
        updated_at = NOW()
    WHERE id = p_client_id;
    
    RETURN v_score;
END;
$$ LANGUAGE plpgsql;

-- Match workers to a job
CREATE OR REPLACE FUNCTION match_job_to_workers(job_id UUID)
RETURNS TABLE(
    worker_id UUID, 
    worker_name TEXT, 
    worker_phone VARCHAR, 
    match_score DECIMAL,
    worker_trade_id UUID
) AS $$
BEGIN
    RETURN QUERY
    WITH job_info AS (
        SELECT j.trade, j.location_city, j.location_subcity, j.id, j.fixed_price_etb
        FROM jobs j WHERE j.id = job_id
    )
    SELECT 
        wms.worker_id,
        wms.full_name,
        wms.phone_number,
        wms.match_score + wms.response_bonus,
        wt.id as worker_trade_id
    FROM worker_match_scores wms
    JOIN worker_trades wt ON wms.worker_id = wt.worker_id AND wt.trade = wms.trade
    CROSS JOIN job_info ji
    WHERE wms.trade = ji.trade
      AND wms.city = ji.location_city
      AND wms.is_available = TRUE
    ORDER BY match_score DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- Create booking when worker accepts job
CREATE OR REPLACE FUNCTION accept_job_booking(
    p_job_id UUID, 
    p_worker_id UUID,
    p_worker_trade_id UUID
) RETURNS UUID AS $$
DECLARE
    v_booking_id UUID;
    v_job_status job_status;
    v_fee_percentage DECIMAL(5,2);
BEGIN
    SELECT (config_value->>'service_fee_percentage')::DECIMAL INTO v_fee_percentage
    FROM system_config WHERE config_key = 'fees';
    
    SELECT status INTO v_job_status FROM jobs WHERE id = p_job_id;
    
    IF v_job_status != 'matched' AND v_job_status != 'posted' THEN
        RAISE EXCEPTION 'Job is no longer available';
    END IF;
    
    INSERT INTO bookings (
        job_id, client_id, client_profile_id, worker_id, worker_trade_id, 
        fixed_price_etb, platform_fee_etb, worker_payout_etb, status
    )
    SELECT 
        j.id,
        j.client_id,
        j.client_profile_id,
        wp.id,
        wt.id,
        j.fixed_price_etb,
        ROUND(j.fixed_price_etb * v_fee_percentage / 100, 2),
        ROUND(j.fixed_price_etb * (1 - v_fee_percentage / 100), 2),
        'accepted'
    FROM jobs j
    JOIN worker_profiles wp ON wp.id = p_worker_id
    JOIN worker_trades wt ON wt.id = p_worker_trade_id AND wt.trade = j.trade
    WHERE j.id = p_job_id
    RETURNING bookings.id INTO v_booking_id;
    
    UPDATE jobs SET status = 'accepted', updated_at = NOW()
    WHERE id = p_job_id;
    
    UPDATE job_matches SET status = 'expired' 
    WHERE job_id = p_job_id AND worker_id != p_worker_id;
    
    INSERT INTO booking_timeline (booking_id, event, details)
    VALUES (v_booking_id, 'accepted', 'Worker accepted the job');
    
    RETURN v_booking_id;
END;
$$ LANGUAGE plpgsql;

-- Process payment for completed booking
CREATE OR REPLACE FUNCTION process_payment(
    p_booking_id UUID,
    p_payment_method_id UUID
) RETURNS UUID AS $$
DECLARE
    v_payment_id UUID;
    v_booking_status booking_status;
BEGIN
    SELECT status INTO v_booking_status FROM bookings WHERE id = p_booking_id;
    
    IF v_booking_status != 'completed' THEN
        RAISE EXCEPTION 'Booking must be completed before payment';
    END IF;
    
    IF EXISTS (SELECT 1 FROM payments WHERE booking_id = p_booking_id AND status = 'completed') THEN
        RAISE EXCEPTION 'Payment already completed for this booking';
    END IF;
    
    INSERT INTO payments (
        booking_id, client_id, worker_id, payment_method_id,
        amount_etb, service_fee_etb, worker_payout_etb, status
    )
    SELECT 
        b.id, b.client_id, b.worker_id, p_payment_method_id,
        b.fixed_price_etb, b.platform_fee_etb, b.worker_payout_etb,
        'pending'
    FROM bookings b
    WHERE b.id = p_booking_id
    RETURNING payments.id INTO v_payment_id;
    
    UPDATE bookings SET status = 'paid', updated_at = NOW()
    WHERE id = p_booking_id;
    
    UPDATE jobs SET status = 'paid', updated_at = NOW()
    FROM bookings b WHERE b.job_id = jobs.id AND b.id = p_booking_id;
    
    RETURN v_payment_id;
END;
$$ LANGUAGE plpgsql;

-- Encrypt sensitive data
CREATE OR REPLACE FUNCTION encrypt_sensitive_data(p_data TEXT, p_key TEXT DEFAULT current_setting('app.encryption_key'))
RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(p_data, p_key);
END;
$$ LANGUAGE plpgsql;

-- Decrypt sensitive data
CREATE OR REPLACE FUNCTION decrypt_sensitive_data(p_encrypted BYTEA, p_key TEXT DEFAULT current_setting('app.encryption_key'))
RETURNS TEXT AS $$
BEGIN
    RETURN pgp_sym_decrypt(p_encrypted, p_key);
END;
$$ LANGUAGE plpgsql;

-- Archive old SMS logs
CREATE OR REPLACE FUNCTION archive_old_sms_logs()
RETURNS void AS $$
BEGIN
    CREATE TABLE IF NOT EXISTS sms_logs_archive (LIKE sms_logs INCLUDING ALL);
    
    INSERT INTO sms_logs_archive 
    SELECT * FROM sms_logs 
    WHERE created_at < NOW() - INTERVAL '90 days';
    
    DELETE FROM sms_logs 
    WHERE created_at < NOW() - INTERVAL '90 days';
    
    DELETE FROM otp_codes 
    WHERE created_at < NOW() - INTERVAL '30 days';
    
    DELETE FROM otp_rate_limits 
    WHERE window_start < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- Archive old jobs
CREATE OR REPLACE FUNCTION archive_old_jobs()
RETURNS void AS $$
BEGIN
    UPDATE jobs 
    SET status = 'archived' 
    WHERE created_at < NOW() - INTERVAL '3 years'
      AND status IN ('completed', 'paid', 'cancelled');
END;
$$ LANGUAGE plpgsql;