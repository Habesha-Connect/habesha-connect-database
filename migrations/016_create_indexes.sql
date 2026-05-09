-- Migration 016: Create Database Indexes
-- Description: Performance indexes for all tables
-- Dependencies: All previous table migrations

-- Users indexes
CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_active ON users(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_users_suspended ON users(is_suspended) WHERE is_suspended = TRUE;

-- OTP indexes
CREATE INDEX idx_otp_phone_purpose ON otp_codes(phone_number, purpose, is_used);
CREATE INDEX idx_otp_expires ON otp_codes(expires_at) WHERE is_used = FALSE AND attempts < max_attempts;
CREATE INDEX idx_otp_televeret ON otp_codes(televeret_message_id) WHERE televeret_message_id IS NOT NULL;

-- Rate limit indexes
CREATE INDEX idx_otp_rate_limits_phone ON otp_rate_limits(phone_number, window_start DESC);
CREATE INDEX idx_otp_rate_limits_window ON otp_rate_limits(window_start);

-- Account lockout indexes
CREATE INDEX idx_lockouts_phone ON account_lockouts(phone_number, locked_until DESC);
CREATE INDEX idx_lockouts_active ON account_lockouts(locked_until) WHERE locked_until > NOW();

-- Client profile indexes
CREATE INDEX idx_client_verification ON client_profiles(verification_status);
CREATE INDEX idx_client_trust_score ON client_profiles(trust_score DESC);
CREATE INDEX idx_client_trust_level ON client_profiles(trust_level);
CREATE INDEX idx_client_location ON client_profiles(address_city, address_subcity);

-- Client trust score indexes
CREATE INDEX idx_trust_scores_value ON client_trust_scores(overall_score DESC);
CREATE INDEX idx_trust_scores_updated ON client_trust_scores(last_calculated_at);

-- Client flags indexes
CREATE INDEX idx_client_flags_active ON client_flags(status) WHERE status = 'active';
CREATE INDEX idx_client_flags_severity ON client_flags(severity);

-- Payment methods indexes
CREATE INDEX idx_payment_methods_client ON client_payment_methods(client_id, is_default);
CREATE INDEX idx_payment_verified ON client_payment_methods(is_verified) WHERE is_verified = TRUE;

-- Worker profile indexes
CREATE INDEX idx_worker_verification ON worker_profiles(verification_status);
CREATE INDEX idx_worker_location ON worker_profiles(city, sub_city, woreda);
CREATE INDEX idx_worker_available ON worker_profiles(is_available) WHERE is_available = TRUE;
CREATE INDEX idx_worker_rating ON worker_profiles(total_jobs_completed DESC, verification_status);

-- Worker trades indexes
CREATE INDEX idx_worker_trades_status ON worker_trades(verification_status);
CREATE INDEX idx_worker_trades_type ON worker_trades(trade);
CREATE INDEX idx_worker_trades_verified ON worker_trades(verification_status) WHERE verification_status = 'verified';

-- Verifier indexes
CREATE INDEX idx_verifier_active ON verifier_profiles(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_verifier_location ON verifier_profiles(city, sub_city);

-- Verification sessions indexes
CREATE INDEX idx_verification_status ON verification_sessions(status);
CREATE INDEX idx_verification_verifier ON verification_sessions(verifier_id, status);
CREATE INDEX idx_verification_meeting ON verification_sessions(meeting_date) WHERE status = 'scheduled';

-- Fixed pricing indexes
CREATE INDEX idx_pricing_trade_active ON fixed_price_jobs(trade, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_pricing_name ON fixed_price_jobs(job_name);

-- Jobs indexes
CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_jobs_trade ON jobs(trade);
CREATE INDEX idx_jobs_client ON jobs(client_id, status);
CREATE INDEX idx_jobs_location ON jobs(location_city, location_subcity);
CREATE INDEX idx_jobs_date ON jobs(preferred_date) WHERE status IN ('posted', 'matched', 'accepted');
CREATE INDEX idx_jobs_created ON jobs(created_at DESC);
CREATE INDEX idx_jobs_expires ON jobs(expires_at) WHERE status = 'posted';

-- Job matches indexes
CREATE INDEX idx_matches_job ON job_matches(job_id, status);
CREATE INDEX idx_matches_worker ON job_matches(worker_id, status);
CREATE INDEX idx_matches_status ON job_matches(status);

-- Bookings indexes
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_client ON bookings(client_id);
CREATE INDEX idx_bookings_worker ON bookings(worker_id);
CREATE INDEX idx_bookings_date ON bookings(created_at DESC);

-- Payments indexes
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_gateway ON payments(gateway, gateway_transaction_id);
CREATE INDEX idx_payments_client ON payments(client_id);
CREATE INDEX idx_payments_worker ON payments(worker_id);
CREATE INDEX idx_payments_date ON payments(created_at DESC);

-- SMS logs indexes
CREATE INDEX idx_sms_phone ON sms_logs(recipient_phone);
CREATE INDEX idx_sms_type ON sms_logs(notification_type);
CREATE INDEX idx_sms_status ON sms_logs(televeret_status);
CREATE INDEX idx_sms_created ON sms_logs(created_at DESC);
CREATE INDEX idx_sms_retention ON sms_logs(created_at) WHERE created_at < NOW() - INTERVAL '90 days';
CREATE INDEX idx_sms_reference ON sms_logs(reference_id, reference_type);

-- SMS cost tracking indexes
CREATE INDEX idx_sms_cost_date ON sms_cost_tracking(billed_at DESC);
CREATE INDEX idx_sms_cost_phone ON sms_cost_tracking(phone_number);

-- Audit logs indexes
CREATE INDEX idx_audit_admin ON admin_audit_logs(admin_id);
CREATE INDEX idx_audit_entity ON admin_audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_action ON admin_audit_logs(action);
CREATE INDEX idx_audit_created ON admin_audit_logs(created_at DESC);

-- Disputes indexes
CREATE INDEX idx_disputes_status ON disputes(status);
CREATE INDEX idx_disputes_booking ON disputes(booking_id);
CREATE INDEX idx_disputes_filer ON disputes(filed_by_user_id);
CREATE INDEX idx_disputes_date ON disputes(created_at DESC);

-- Ratings indexes
CREATE INDEX idx_ratings_user ON ratings(rated_user_id, rating);
CREATE INDEX idx_ratings_booking ON ratings(booking_id);
CREATE INDEX idx_ratings_created ON ratings(created_at DESC);

-- User reports indexes
CREATE INDEX idx_reports_status ON user_reports(status) WHERE status = 'pending';
CREATE INDEX idx_reports_reported_user ON user_reports(reported_user_id);

-- In-app notifications indexes
CREATE INDEX idx_notifications_user ON in_app_notifications(user_id, is_read);
CREATE INDEX idx_notifications_created ON in_app_notifications(created_at DESC);

-- Sessions indexes
CREATE INDEX idx_sessions_user ON user_sessions(user_id, is_active);
CREATE INDEX idx_sessions_token ON user_sessions(session_token);
CREATE INDEX idx_sessions_expires ON user_sessions(expires_at) WHERE is_active = TRUE;