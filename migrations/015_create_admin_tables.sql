-- Migration 015: Create Admin & System Tables
-- Description: Audit logging and system configuration
-- Dependencies: 003

CREATE TABLE admin_audit_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id        UUID REFERENCES users(id),
    action          VARCHAR(100) NOT NULL,
    entity_type     VARCHAR(50),
    entity_id       UUID,
    old_value       JSONB,
    new_value       JSONB,
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- System configuration
CREATE TABLE system_config (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_key      VARCHAR(100) UNIQUE NOT NULL,
    config_value    JSONB NOT NULL,
    description     TEXT,
    updated_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default configuration values
INSERT INTO system_config (config_key, config_value, description) VALUES
('fees', '{"service_fee_percentage": 10.00, "min_fee_etb": 50.00, "max_fee_etb": 500.00}', 'Platform fee structure'),
('matching', '{"max_workers_matched": 10, "match_radius_km": 15, "expiry_hours": 24, "max_concurrent_jobs_per_worker": 3}', 'Job matching parameters'),
('disputes', '{"filing_window_hours": 48, "auto_resolve_hours": 168, "max_strikes_before_suspension": 3}', 'Dispute resolution parameters'),
('notifications', '{"reminder_before_job_minutes": 60, "rating_reminder_after_hours": 24, "payment_reminder_after_hours": 48}', 'Notification timing'),
('otp', '{"rate_limit_per_hour": 3, "expiry_seconds": 300, "max_attempts": 3, "lockout_minutes": 15}', 'OTP security settings');