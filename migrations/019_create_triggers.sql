-- Migration 019: Create Database Triggers
-- Description: Automatic timestamp updates, trust score recalculation, audit logging
-- Dependencies: All table and function migrations

-- Auto-update updated_at column function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers to relevant tables
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_client_profiles_updated_at 
    BEFORE UPDATE ON client_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_worker_profiles_updated_at 
    BEFORE UPDATE ON worker_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_jobs_updated_at 
    BEFORE UPDATE ON jobs 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at 
    BEFORE UPDATE ON bookings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at 
    BEFORE UPDATE ON payments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_disputes_updated_at 
    BEFORE UPDATE ON disputes 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ratings_updated_at 
    BEFORE UPDATE ON ratings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notification_preferences_updated_at 
    BEFORE UPDATE ON notification_preferences 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sms_templates_updated_at 
    BEFORE UPDATE ON sms_templates 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trust score recalculation trigger
CREATE OR REPLACE FUNCTION trigger_trust_score_update()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM calculate_client_trust_score(NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_client_trust_after_profile_change 
    AFTER UPDATE ON client_profiles 
    FOR EACH ROW 
    WHEN (OLD.verification_status IS DISTINCT FROM NEW.verification_status 
       OR OLD.payment_method_verified IS DISTINCT FROM NEW.payment_method_verified)
    EXECUTE FUNCTION trigger_trust_score_update();

-- Admin action logging trigger
CREATE OR REPLACE FUNCTION log_admin_action()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO admin_audit_logs (admin_id, action, entity_type, entity_id, old_value, new_value)
    VALUES (
        current_setting('app.current_admin_id', TRUE)::UUID,
        TG_OP,
        TG_TABLE_NAME,
        NEW.id,
        CASE WHEN TG_OP = 'UPDATE' THEN row_to_json(OLD)::JSONB ELSE NULL END,
        row_to_json(NEW)::JSONB
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;