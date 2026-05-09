-- Habesha Connect Database Schema v2.0
-- PostgreSQL 16+
-- Complete schema for the Habesha Connect platform

-- ============================================
-- 1. EXTENSIONS
-- ============================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- 2. ENUM TYPES
-- ============================================
CREATE TYPE user_role AS ENUM ('client', 'worker', 'verifier', 'admin');
CREATE TYPE trade_type AS ENUM (
    'electrician', 'plumber', 'carpenter', 'mason', 
    'painter', 'cleaner', 'other'
);
CREATE TYPE verification_status AS ENUM (
    'unverified', 'pending', 'in_progress', 'verified', 'failed', 'revoked'
);
CREATE TYPE test_result AS ENUM ('pass', 'fail');
CREATE TYPE job_status AS ENUM (
    'posted', 'matched', 'accepted', 'rejected', 'in_progress', 
    'completed', 'paid', 'disputed', 'cancelled', 'expired', 'archived'
);
CREATE TYPE payment_status AS ENUM (
    'pending', 'processing', 'completed', 'failed', 'refunded'
);
CREATE TYPE dispute_status AS ENUM ('open', 'under_review', 'resolved', 'closed');
CREATE TYPE dispute_filed_by AS ENUM ('client', 'worker');
CREATE TYPE language_preference AS ENUM ('amharic', 'english');
CREATE TYPE notification_type AS ENUM (
    'otp', 'job_match', 'job_accepted', 'job_rejected', 'reminder', 
    'payment_confirmation', 'payment_receipt', 'rating_request', 
    'dispute_update', 'verification_update', 'system', 'welcome'
);
CREATE TYPE sms_status AS ENUM ('queued', 'sent', 'delivered', 'failed', 'bounced');
CREATE TYPE otp_purpose AS ENUM (
    'login', 'registration', 'payment_confirmation', 'admin_mfa', 'phone_verification'
);
CREATE TYPE flag_type AS ENUM (
    'payment_issue', 'fake_job', 'harassment', 'no_show', 
    'property_damage_threat', 'inappropriate_behavior', 'other'
);
CREATE TYPE flag_severity AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE flag_status AS ENUM ('active', 'resolved', 'dismissed');
CREATE TYPE document_type AS ENUM (
    'id_card', 'utility_bill', 'property_deed', 'rental_agreement', 'selfie_with_id'
);
CREATE TYPE payment_method_type AS ENUM ('telebirr', 'chapa', 'bank_transfer');
CREATE TYPE trust_level AS ENUM ('trusted', 'standard', 'caution', 'high_risk');
CREATE TYPE booking_status AS ENUM (
    'pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled'
);

-- ============================================
-- 3. USERS & AUTHENTICATION
-- ============================================

-- Main users table
CREATE TABLE users (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number        VARCHAR(15) UNIQUE NOT NULL,
    full_name           VARCHAR(100) NOT NULL,
    role                user_role NOT NULL,
    email               VARCHAR(255) UNIQUE,
    language_pref       language_preference DEFAULT 'amharic',
    is_active           BOOLEAN DEFAULT TRUE,
    is_suspended        BOOLEAN DEFAULT FALSE,
    is_banned           BOOLEAN DEFAULT FALSE,
    suspended_reason    TEXT,
    suspended_at        TIMESTAMPTZ,
    suspended_until     TIMESTAMPTZ,
    banned_at           TIMESTAMPTZ,
    phone_verified      BOOLEAN DEFAULT FALSE,
    phone_verified_at   TIMESTAMPTZ,
    last_login_at       TIMESTAMPTZ,
    last_activity_at    TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT valid_phone CHECK (phone_number ~ '^\+251[0-9]{9}$')
);

-- OTP Codes (Enhanced with TeleRivet tracking)
CREATE TABLE otp_codes (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number            VARCHAR(15) NOT NULL,
    code                    VARCHAR(6) NOT NULL,
    purpose                 otp_purpose NOT NULL,
    televeret_message_id    VARCHAR(255),
    televeret_status        sms_status DEFAULT 'queued',
    is_used                 BOOLEAN DEFAULT FALSE,
    attempts                INTEGER DEFAULT 0,
    max_attempts            INTEGER DEFAULT 3,
    expires_at              TIMESTAMPTZ NOT NULL,
    verified_at             TIMESTAMPTZ,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT valid_otp_code CHECK (code ~ '^[0-9]{6}$')
);

-- OTP Rate Limiting
CREATE TABLE otp_rate_limits (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number    VARCHAR(15) NOT NULL,
    request_count   INTEGER DEFAULT 1,
    window_start    TIMESTAMPTZ DEFAULT NOW(),
    window_type     VARCHAR(20) DEFAULT 'hourly', -- 'hourly', 'daily'
    CONSTRAINT unique_phone_window UNIQUE (phone_number, window_start, window_type)
);

-- Account Lockouts
CREATE TABLE account_lockouts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number    VARCHAR(15) NOT NULL,
    locked_at       TIMESTAMPTZ DEFAULT NOW(),
    locked_until    TIMESTAMPTZ NOT NULL,
    reason          VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Terms & Conditions acceptance tracking
CREATE TABLE terms_acceptance (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    terms_version   VARCHAR(20) NOT NULL,
    ip_address      INET,
    user_agent      TEXT,
    accepted_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Terms versions
CREATE TABLE terms_versions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    version             VARCHAR(20) UNIQUE NOT NULL,
    effective_date      DATE NOT NULL,
    content_amharic     TEXT,
    content_english     TEXT,
    summary_amharic     TEXT,
    summary_english     TEXT,
    is_active           BOOLEAN DEFAULT TRUE,
    created_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Admin MFA tokens
CREATE TABLE admin_mfa (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id        UUID REFERENCES users(id) ON DELETE CASCADE,
    email           VARCHAR(255) NOT NULL,
    otp_code        VARCHAR(6) NOT NULL,
    is_used         BOOLEAN DEFAULT FALSE,
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Refresh tokens
CREATE TABLE refresh_tokens (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    token_hash      VARCHAR(64) UNIQUE NOT NULL,
    expires_at      TIMESTAMPTZ NOT NULL,
    is_revoked      BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- User sessions
CREATE TABLE user_sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    session_token   VARCHAR(64) UNIQUE NOT NULL,
    ip_address      INET,
    user_agent      TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    expires_at      TIMESTAMPTZ NOT NULL,
    last_activity   TIMESTAMPTZ DEFAULT NOW(),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 4. CLIENT PROFILES & VERIFICATION
-- ============================================

CREATE TABLE client_profiles (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    verification_status     verification_status DEFAULT 'unverified',
    trust_level             trust_level DEFAULT 'standard',
    trust_score             DECIMAL(3,2) DEFAULT 5.00 CHECK (trust_score BETWEEN 0.00 AND 10.00),
    id_type                 VARCHAR(50), -- 'national_id', 'passport', 'drivers_license'
    id_number_hash          VARCHAR(64), -- Hashed for privacy
    address_city            VARCHAR(100),
    address_subcity         VARCHAR(100),
    address_woreda          VARCHAR(100),
    full_address            TEXT,
    payment_method_verified BOOLEAN DEFAULT FALSE,
    phone_verified          BOOLEAN DEFAULT FALSE,
    total_jobs_posted       INTEGER DEFAULT 0,
    total_jobs_completed    INTEGER DEFAULT 0,
    total_spent_etb         DECIMAL(12,2) DEFAULT 0.00,
    cancellation_rate       DECIMAL(3,2) DEFAULT 0.00,
    dispute_rate            DECIMAL(3,2) DEFAULT 0.00,
    avg_payment_time_hours  DECIMAL(5,1),
    is_verified             BOOLEAN DEFAULT FALSE,
    verified_at             TIMESTAMPTZ,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- Client verification documents
CREATE TABLE client_verification_documents (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id       UUID REFERENCES client_profiles(id) ON DELETE CASCADE,
    document_type   document_type NOT NULL,
    document_url    TEXT NOT NULL,
    thumbnail_url   TEXT,
    verification_status verification_status DEFAULT 'pending',
    reviewed_by     UUID REFERENCES users(id),
    review_notes    TEXT,
    submitted_at    TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at     TIMESTAMPTZ
);

-- Client payment methods
CREATE TABLE client_payment_methods (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id           UUID REFERENCES client_profiles(id) ON DELETE CASCADE,
    payment_type        payment_method_type NOT NULL,
    account_identifier  VARCHAR(255) NOT NULL,
    account_identifier_hash VARCHAR(64), -- For lookup without exposure
    is_verified         BOOLEAN DEFAULT FALSE,
    is_default          BOOLEAN DEFAULT FALSE,
    verification_method VARCHAR(50), -- 'micro_deposit', 'otp', 'manual'
    verification_code   VARCHAR(10),
    verified_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Client trust scores
CREATE TABLE client_trust_scores (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id               UUID UNIQUE REFERENCES client_profiles(id) ON DELETE CASCADE,
    overall_score           DECIMAL(3,2) DEFAULT 5.00 CHECK (overall_score BETWEEN 0.00 AND 10.00),
    verification_score      DECIMAL(3,2) DEFAULT 0.00,
    payment_reliability     DECIMAL(3,2) DEFAULT 5.00,
    communication_score     DECIMAL(3,2) DEFAULT 5.00,
    cancellation_penalty    DECIMAL(3,2) DEFAULT 0.00,
    dispute_penalty         DECIMAL(3,2) DEFAULT 0.00,
    total_ratings_received  INTEGER DEFAULT 0,
    avg_worker_rating       DECIMAL(2,1) DEFAULT 0.0,
    last_calculated_at      TIMESTAMPTZ DEFAULT NOW(),
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- Client flagging system
CREATE TABLE client_flags (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id       UUID REFERENCES client_profiles(id) ON DELETE CASCADE,
    flag_type       flag_type NOT NULL,
    severity        flag_severity DEFAULT 'medium',
    description     TEXT NOT NULL,
    reported_by     UUID REFERENCES users(id),
    job_id          UUID REFERENCES jobs(id),
    booking_id      UUID REFERENCES bookings(id),
    status          flag_status DEFAULT 'active',
    resolved_by     UUID REFERENCES users(id),
    resolution_notes TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

-- ============================================
-- 5. WORKER PROFILES & VERIFICATION
-- ============================================

CREATE TABLE worker_profiles (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    government_id_encrypted BYTEA, -- Encrypted with pgcrypto
    government_id_hash  VARCHAR(64), -- For lookup without decryption
    years_of_experience INTEGER CHECK (years_of_experience >= 0),
    city                VARCHAR(100) NOT NULL,
    sub_city            VARCHAR(100),
    woreda              VARCHAR(100),
    is_available        BOOLEAN DEFAULT TRUE,
    availability_reason TEXT,
    verification_status verification_status DEFAULT 'unverified',
    profile_image_url   TEXT,
    total_jobs_completed INTEGER DEFAULT 0,
    total_earnings_etb  DECIMAL(12,2) DEFAULT 0.00,
    avg_response_time_minutes INTEGER,
    acceptance_rate     DECIMAL(3,1),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Worker trades (many-to-many with verification per trade)
CREATE TABLE worker_trades (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    worker_id           UUID REFERENCES worker_profiles(id) ON DELETE CASCADE,
    trade               trade_type NOT NULL,
    verification_status verification_status DEFAULT 'unverified',
    verified_at         TIMESTAMPTZ,
    revoked_at          TIMESTAMPTZ,
    revoked_reason      TEXT,
    revoked_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(worker_id, trade)
);

-- Verifier profiles (vocational teachers)
CREATE TABLE verifier_profiles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    institution     VARCHAR(200),
    qualification   VARCHAR(200),
    employee_id     VARCHAR(50),
    city            VARCHAR(100) NOT NULL,
    sub_city        VARCHAR(100),
    trades_can_verify trade_type[] DEFAULT '{}',
    is_active       BOOLEAN DEFAULT TRUE,
    total_tests     INTEGER DEFAULT 0,
    avg_rating      DECIMAL(2,1),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Verification assignments
CREATE TABLE verification_sessions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    worker_trade_id     UUID REFERENCES worker_trades(id) ON DELETE CASCADE,
    verifier_id         UUID REFERENCES verifier_profiles(id),
    status              verification_status DEFAULT 'pending',
    meeting_location    TEXT,
    meeting_address     TEXT,
    meeting_date        DATE,
    meeting_time        TIME,
    meeting_notes       TEXT,
    meeting_attended    BOOLEAN,
    practical_result    test_result,
    practical_score     INTEGER CHECK (practical_score BETWEEN 0 AND 100),
    practical_comments  TEXT,
    theoretical_result  test_result,
    theoretical_score   INTEGER CHECK (theoretical_score BETWEEN 0 AND 100),
    theoretical_comments TEXT,
    overall_result      test_result,
    overall_comments    TEXT,
    completed_at        TIMESTAMPTZ,
    sms_reminder_sent   BOOLEAN DEFAULT FALSE,
    sms_reminder_sent_at TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 6. FIXED PRICING SYSTEM
-- ============================================

CREATE TABLE fixed_price_jobs (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trade               trade_type NOT NULL,
    job_name            VARCHAR(200) NOT NULL,
    description         TEXT,
    price_etb           DECIMAL(10,2) NOT NULL CHECK (price_etb > 0),
    estimated_duration  VARCHAR(50), -- e.g., '2-3 hours', '1 day'
    includes            TEXT[] DEFAULT '{}',
    excludes            TEXT[] DEFAULT '{}',
    is_active           BOOLEAN DEFAULT TRUE,
    created_by          UUID REFERENCES users(id),
    updated_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Price history for auditing
CREATE TABLE fixed_price_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    price_id        UUID REFERENCES fixed_price_jobs(id) ON DELETE CASCADE,
    old_price_etb   DECIMAL(10,2),
    new_price_etb   DECIMAL(10,2),
    changed_by      UUID REFERENCES users(id),
    change_reason   TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 7. JOBS & MATCHING
-- ============================================

CREATE TABLE jobs (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id           UUID REFERENCES users(id) ON DELETE CASCADE,
    client_profile_id   UUID REFERENCES client_profiles(id),
    fixed_price_id      UUID REFERENCES fixed_price_jobs(id),
    trade               trade_type NOT NULL,
    job_type            VARCHAR(200) NOT NULL,
    description         TEXT CHECK (char_length(description) BETWEEN 20 AND 500),
    special_instructions TEXT,
    preferred_date      DATE,
    preferred_time      TIME,
    location_address    TEXT NOT NULL,
    location_city       VARCHAR(100),
    location_subcity    VARCHAR(100),
    location_coordinates POINT, -- For proximity matching
    fixed_price_etb     DECIMAL(10,2) NOT NULL,
    status              job_status DEFAULT 'posted',
    client_verified     BOOLEAN DEFAULT FALSE,
    client_trust_score  DECIMAL(3,2),
    matching_attempts   INTEGER DEFAULT 0,
    max_matches         INTEGER DEFAULT 10,
    expires_at          TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours'),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Job photos
CREATE TABLE job_photos (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id          UUID REFERENCES jobs(id) ON DELETE CASCADE,
    photo_url       TEXT NOT NULL,
    thumbnail_url   TEXT,
    file_size_bytes INTEGER,
    uploaded_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Job matches (eligible workers for a job)
CREATE TABLE job_matches (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id          UUID REFERENCES jobs(id) ON DELETE CASCADE,
    worker_id       UUID REFERENCES worker_profiles(id),
    worker_trade_id UUID REFERENCES worker_trades(id),
    match_score     DECIMAL(3,1),
    status          VARCHAR(20) DEFAULT 'pending', -- pending, notified, accepted, rejected, expired
    sms_sent_at     TIMESTAMPTZ,
    sms_status      sms_status DEFAULT 'queued',
    televeret_message_id VARCHAR(255),
    responded_at    TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 8. BOOKINGS
-- ============================================

CREATE TABLE bookings (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id              UUID UNIQUE REFERENCES jobs(id),
    client_id           UUID REFERENCES users(id),
    client_profile_id   UUID REFERENCES client_profiles(id),
    worker_id           UUID REFERENCES worker_profiles(id),
    worker_trade_id     UUID REFERENCES worker_trades(id),
    fixed_price_etb     DECIMAL(10,2) NOT NULL,
    platform_fee_etb    DECIMAL(10,2),
    worker_payout_etb   DECIMAL(10,2),
    status              booking_status DEFAULT 'accepted',
    client_phone_visible BOOLEAN DEFAULT TRUE,
    worker_phone_visible BOOLEAN DEFAULT TRUE,
    reminder_sent       BOOLEAN DEFAULT FALSE,
    reminder_sent_at    TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    completion_notes    TEXT,
    accepted_at         TIMESTAMPTZ DEFAULT NOW(),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Booking timeline events
CREATE TABLE booking_timeline (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id      UUID REFERENCES bookings(id) ON DELETE CASCADE,
    event           VARCHAR(50) NOT NULL, -- created, accepted, reminded, completed, paid, disputed
    details         TEXT,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 9. PAYMENTS
-- ============================================

CREATE TABLE payments (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id              UUID REFERENCES bookings(id),
    client_id               UUID REFERENCES users(id),
    worker_id               UUID REFERENCES worker_profiles(id),
    payment_method_id       UUID REFERENCES client_payment_methods(id),
    amount_etb              DECIMAL(10,2) NOT NULL,
    service_fee_etb         DECIMAL(10,2) NOT NULL,
    worker_payout_etb       DECIMAL(10,2) NOT NULL,
    gateway                 VARCHAR(50), -- telebirr, chapa, bank_transfer
    gateway_transaction_id  VARCHAR(255),
    gateway_reference       VARCHAR(255),
    status                  payment_status DEFAULT 'pending',
    payment_instructions    JSONB,
    completed_at            TIMESTAMPTZ,
    expires_at              TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 minutes'),
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- Payment receipts
CREATE TABLE receipts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id      UUID REFERENCES payments(id),
    receipt_number  VARCHAR(50) UNIQUE NOT NULL,
    client_name     VARCHAR(100), -- Partial name for privacy
    worker_name     VARCHAR(100), -- Partial name for privacy
    amount_etb      DECIMAL(10,2),
    service_fee_etb DECIMAL(10,2),
    worker_payout   DECIMAL(10,2),
    receipt_url     TEXT,
    pdf_url         TEXT,
    generated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Payment gateway logs
CREATE TABLE payment_gateway_logs (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id              UUID REFERENCES payments(id),
    gateway                 VARCHAR(50),
    event                   VARCHAR(50), -- request, callback, webhook
    request_payload         JSONB,
    response_payload        JSONB,
    status_code             INTEGER,
    success                 BOOLEAN,
    created_at              TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 10. RATINGS & REVIEWS
-- ============================================

CREATE TABLE ratings (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id          UUID UNIQUE REFERENCES bookings(id),
    rater_id            UUID REFERENCES users(id),
    rated_user_id       UUID REFERENCES users(id),
    rating              INTEGER CHECK (rating BETWEEN 1 AND 5),
    review_text         TEXT,
    aspects             JSONB, -- {"punctuality": 5, "quality": 5, "communication": 4}
    is_public           BOOLEAN DEFAULT TRUE,
    is_edited           BOOLEAN DEFAULT FALSE,
    edited_at           TIMESTAMPTZ,
    helpful_count       INTEGER DEFAULT 0,
    reported_count      INTEGER DEFAULT 0,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT mandatory_comment_for_low_rating CHECK (
        rating > 2 OR (rating <= 2 AND review_text IS NOT NULL AND char_length(review_text) >= 10)
    )
);

-- Rating reports
CREATE TABLE rating_reports (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rating_id       UUID REFERENCES ratings(id) ON DELETE CASCADE,
    reported_by     UUID REFERENCES users(id),
    reason          TEXT NOT NULL,
    status          VARCHAR(20) DEFAULT 'pending',
    reviewed_by     UUID REFERENCES users(id),
    review_notes    TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at     TIMESTAMPTZ
);

-- ============================================
-- 11. DISPUTES
-- ============================================

CREATE TABLE disputes (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id          UUID REFERENCES bookings(id),
    filed_by            dispute_filed_by NOT NULL,
    filed_by_user_id    UUID REFERENCES users(id),
    description         TEXT NOT NULL,
    desired_outcome     TEXT,
    claims              JSONB, -- {"client_at_fault": true, "worker_at_fault": false}
    status              dispute_status DEFAULT 'open',
    admin_id            UUID REFERENCES users(id),
    admin_notes         TEXT,
    resolution          TEXT,
    resolution_type     VARCHAR(50), -- client_at_fault, worker_at_fault, mutual, inconclusive
    trust_score_impact  DECIMAL(3,2),
    resolved_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Dispute evidence/photos
CREATE TABLE dispute_evidence (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dispute_id      UUID REFERENCES disputes(id) ON DELETE CASCADE,
    evidence_type   VARCHAR(50) NOT NULL, -- photo, document, screenshot
    file_url        TEXT NOT NULL,
    thumbnail_url   TEXT,
    description     TEXT,
    uploaded_by     UUID REFERENCES users(id),
    uploaded_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Dispute timeline
CREATE TABLE dispute_timeline (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dispute_id      UUID REFERENCES disputes(id) ON DELETE CASCADE,
    event           VARCHAR(50) NOT NULL,
    details         TEXT,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 12. NOTIFICATIONS & SMS SYSTEM
-- ============================================

CREATE TABLE sms_logs (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_phone         VARCHAR(15) NOT NULL,
    message_text            TEXT NOT NULL,
    notification_type       notification_type NOT NULL,
    reference_id            UUID, -- job_id, payment_id, booking_id, etc.
    reference_type          VARCHAR(50),
    televeret_message_id    VARCHAR(255),
    televeret_status        sms_status DEFAULT 'queued',
    delivery_time_seconds   INTEGER,
    cost_etb                DECIMAL(10,4),
    error_code              VARCHAR(50),
    error_message           TEXT,
    delivered_at            TIMESTAMPTZ,
    created_at              TIMESTAMPTZ DEFAULT NOW()
);

-- SMS cost tracking
CREATE TABLE sms_cost_tracking (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sms_log_id          UUID REFERENCES sms_logs(id),
    phone_number        VARCHAR(15),
    televeret_cost_etb  DECIMAL(10,4),
    currency            VARCHAR(3) DEFAULT 'ETB',
    billed_at           TIMESTAMPTZ DEFAULT NOW()
);

-- SMS templates
CREATE TABLE sms_templates (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_key    VARCHAR(50) UNIQUE NOT NULL,
    template_name   VARCHAR(100) NOT NULL,
    content_amharic TEXT NOT NULL,
    content_english TEXT NOT NULL,
    variables       TEXT[] DEFAULT '{}',
    is_active       BOOLEAN DEFAULT TRUE,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- User notification preferences
CREATE TABLE notification_preferences (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    sms_notifications       BOOLEAN DEFAULT TRUE,
    email_notifications     BOOLEAN DEFAULT FALSE,
    job_matches             BOOLEAN DEFAULT TRUE,
    reminders               BOOLEAN DEFAULT TRUE,
    payment_updates         BOOLEAN DEFAULT TRUE,
    rating_requests         BOOLEAN DEFAULT TRUE,
    dispute_updates         BOOLEAN DEFAULT TRUE,
    marketing               BOOLEAN DEFAULT FALSE,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- In-app notifications
CREATE TABLE in_app_notifications (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    type            notification_type NOT NULL,
    title           VARCHAR(200) NOT NULL,
    message         TEXT NOT NULL,
    data            JSONB,
    is_read         BOOLEAN DEFAULT FALSE,
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 13. USER REPORTS
-- ============================================

CREATE TABLE user_reports (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id         UUID REFERENCES users(id),
    reported_user_id    UUID REFERENCES users(id),
    job_id              UUID REFERENCES jobs(id),
    booking_id          UUID REFERENCES bookings(id),
    reason              TEXT NOT NULL,
    description         TEXT,
    evidence_urls       TEXT[] DEFAULT '{}',
    status              VARCHAR(20) DEFAULT 'pending', -- pending, reviewed, resolved
    admin_id            UUID REFERENCES users(id),
    admin_notes         TEXT,
    action_taken        VARCHAR(100),
    reviewed_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 14. ADMIN AUDIT & SYSTEM LOGS
-- ============================================

CREATE TABLE admin_audit_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id        UUID REFERENCES users(id),
    action          VARCHAR(100) NOT NULL,
    entity_type     VARCHAR(50), -- user, job, payment, dispute, verification, pricing
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

-- Insert default configuration
INSERT INTO system_config (config_key, config_value, description) VALUES
('fees', '{"service_fee_percentage": 10.00, "min_fee_etb": 50.00, "max_fee_etb": 500.00}', 'Platform fee structure'),
('matching', '{"max_workers_matched": 10, "match_radius_km": 15, "expiry_hours": 24, "max_concurrent_jobs_per_worker": 3}', 'Job matching parameters'),
('disputes', '{"filing_window_hours": 48, "auto_resolve_hours": 168, "max_strikes_before_suspension": 3}', 'Dispute resolution parameters'),
('notifications', '{"reminder_before_job_minutes": 60, "rating_reminder_after_hours": 24, "payment_reminder_after_hours": 48}', 'Notification timing'),
('otp', '{"rate_limit_per_hour": 3, "expiry_seconds": 300, "max_attempts": 3, "lockout_minutes": 15}', 'OTP security settings');

-- ============================================
-- 15. INDEXES
-- ============================================

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

-- ============================================
-- 16. VIEWS FOR COMMON QUERIES
-- ============================================

-- Worker ranking for matching algorithm
CREATE VIEW worker_match_scores AS
SELECT 
    wp.id as worker_id,
    u.full_name,
    u.phone_number,
    wt.trade,
    wp.city,
    wp.sub_city,
    wp.verification_status,
    AVG(r.rating)::DECIMAL(3,2) as avg_rating,
    COUNT(DISTINCT b.id) as completed_jobs,
    COUNT(DISTINCT d.id) as dispute_count,
    wp.years_of_experience,
    wp.is_available,
    -- Composite score for matching priority
    COALESCE(AVG(r.rating), 3.0) * 0.5 + 
    LEAST(COUNT(DISTINCT b.id) * 0.1, 1.0) * 0.3 -
    COUNT(DISTINCT d.id) * 0.2 as match_score,
    -- Response time bonus
    CASE WHEN wp.avg_response_time_minutes <= 15 THEN 0.5 ELSE 0 END as response_bonus
FROM worker_profiles wp
JOIN users u ON wp.user_id = u.id
JOIN worker_trades wt ON wp.id = wt.worker_id
LEFT JOIN bookings b ON wp.id = b.worker_id AND b.status IN ('completed', 'paid')
LEFT JOIN ratings r ON b.id = r.booking_id AND r.rated_user_id = u.id
LEFT JOIN disputes d ON b.id = d.booking_id AND d.status IN ('open', 'under_review')
WHERE u.is_active = TRUE 
  AND u.is_suspended = FALSE
  AND wp.verification_status = 'verified'
  AND wt.verification_status = 'verified'
  AND wp.is_available = TRUE
GROUP BY wp.id, u.full_name, u.phone_number, wt.trade, wp.city, 
         wp.sub_city, wp.verification_status, wp.years_of_experience,
         wp.is_available, wp.avg_response_time_minutes;

-- Client trust overview
CREATE VIEW client_trust_overview AS
SELECT 
    cp.id as client_id,
    cp.user_id,
    u.full_name,
    cp.verification_status,
    cp.trust_level,
    cp.trust_score,
    cts.payment_reliability,
    cts.communication_score,
    cp.total_jobs_posted,
    cp.total_jobs_completed,
    cp.total_spent_etb,
    cp.dispute_rate,
    cp.avg_payment_time_hours,
    COUNT(cf.id) FILTER (WHERE cf.status = 'active') as active_flags,
    COUNT(cf.id) FILTER (WHERE cf.severity = 'critical' AND cf.status = 'active') as critical_flags
FROM client_profiles cp
JOIN users u ON cp.user_id = u.id
LEFT JOIN client_trust_scores cts ON cp.id = cts.client_id
LEFT JOIN client_flags cf ON cp.id = cf.client_id
WHERE u.is_active = TRUE
GROUP BY cp.id, cp.user_id, u.full_name, cp.verification_status, cp.trust_level,
         cp.trust_score, cts.payment_reliability, cts.communication_score,
         cp.total_jobs_posted, cp.total_jobs_completed, cp.total_spent_etb,
         cp.dispute_rate, cp.avg_payment_time_hours;

-- Payment summary for financial reports
CREATE VIEW payment_summary AS
SELECT 
    DATE_TRUNC('month', p.completed_at) as month,
    p.gateway,
    COUNT(p.id) as total_payments,
    SUM(p.amount_etb) as total_amount,
    SUM(p.service_fee_etb) as total_service_fees,
    SUM(p.worker_payout_etb) as total_payouts,
    AVG(p.service_fee_etb / NULLIF(p.amount_etb, 0) * 100) as avg_fee_percentage,
    COUNT(DISTINCT p.client_id) as unique_clients,
    COUNT(DISTINCT p.worker_id) as unique_workers
FROM payments p
WHERE p.status = 'completed'
GROUP BY DATE_TRUNC('month', p.completed_at), p.gateway
ORDER BY month DESC;

-- Active jobs dashboard
CREATE VIEW active_jobs_view AS
SELECT 
    j.id as job_id,
    j.trade,
    j.job_type,
    j.description,
    j.preferred_date,
    j.preferred_time,
    j.location_address,
    j.location_city,
    j.fixed_price_etb,
    j.status,
    j.created_at,
    c.full_name as client_name,
    c.phone_number as client_phone,
    cp.trust_level as client_trust_level,
    cp.trust_score as client_trust_score,
    w.full_name as worker_name,
    w.phone_number as worker_phone,
    wp.verification_status as worker_verification,
    CASE 
        WHEN j.status IN ('posted', 'matched') THEN 
            EXTRACT(EPOCH FROM (NOW() - j.created_at))/3600
        ELSE NULL 
    END as hours_waiting
FROM jobs j
JOIN users c ON j.client_id = c.id
LEFT JOIN client_profiles cp ON j.client_profile_id = cp.id
LEFT JOIN bookings b ON j.id = b.job_id
LEFT JOIN worker_profiles wp ON b.worker_id = wp.id
LEFT JOIN users w ON wp.user_id = w.id
WHERE j.status IN ('posted', 'matched', 'accepted', 'in_progress');

-- SMS delivery analytics
CREATE VIEW sms_delivery_stats AS
SELECT 
    DATE_TRUNC('day', sl.created_at) as day,
    sl.notification_type,
    sl.televeret_status,
    COUNT(*) as count,
    AVG(sl.delivery_time_seconds) as avg_delivery_seconds,
    SUM(sl.cost_etb) as total_cost_etb
FROM sms_logs sl
WHERE sl.created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', sl.created_at), sl.notification_type, sl.televeret_status
ORDER BY day DESC;

-- ============================================
-- 17. STORED PROCEDURES & FUNCTIONS
-- ============================================

-- Function to calculate client trust score
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
    -- Verification score (0-10 based on completed verifications)
    SELECT 
        CASE 
            WHEN phone_verified AND payment_method_verified AND verification_status = 'verified' THEN 10.0
            WHEN phone_verified AND payment_method_verified THEN 7.0
            WHEN phone_verified THEN 4.0
            ELSE 0.0
        END INTO v_verification_score
    FROM client_profiles WHERE id = p_client_id;
    
    -- Payment reliability (based on average payment time)
    SELECT 
        CASE 
            WHEN avg_payment_time_hours <= 1 THEN 10.0
            WHEN avg_payment_time_hours <= 4 THEN 8.0
            WHEN avg_payment_time_hours <= 12 THEN 6.0
            WHEN avg_payment_time_hours <= 24 THEN 4.0
            ELSE 2.0
        END INTO v_payment_score
    FROM client_profiles WHERE id = p_client_id;
    
    -- Communication score (based on worker ratings)
    SELECT COALESCE(AVG(aspect_score), 5.0) INTO v_communication_score
    FROM ratings r,
    jsonb_each_text(r.aspects) AS aspect(key, value),
    LATERAL (SELECT value::DECIMAL AS aspect_score WHERE key = 'communication') sub
    WHERE r.rated_user_id IN (
        SELECT user_id FROM client_profiles WHERE id = p_client_id
    );
    
    -- Cancellation penalty
    SELECT LEAST(cancellation_rate * 20, 5.0) INTO v_cancellation_penalty
    FROM client_profiles WHERE id = p_client_id;
    
    -- Dispute penalty
    SELECT LEAST(dispute_rate * 30, 5.0) INTO v_dispute_penalty
    FROM client_profiles WHERE id = p_client_id;
    
    -- Calculate final score
    v_score := (v_verification_score * 0.3 + 
                v_payment_score * 0.3 + 
                v_communication_score * 0.2 + 
                (10.0 - v_cancellation_penalty) * 0.1 +
                (10.0 - v_dispute_penalty) * 0.1);
    
    -- Update trust score
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
    
    -- Update trust level
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

-- Function to match jobs to workers
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

-- Function to create booking on worker acceptance
CREATE OR REPLACE FUNCTION accept_job_booking(
    p_job_id UUID, 
    p_worker_id UUID,
    p_worker_trade_id UUID
) RETURNS UUID AS $$
DECLARE
    v_booking_id UUID;
    v_job_status job_status;
    v_service_fee DECIMAL(10,2);
    v_fee_percentage DECIMAL(5,2);
BEGIN
    -- Get fee configuration
    SELECT (config_value->>'service_fee_percentage')::DECIMAL INTO v_fee_percentage
    FROM system_config WHERE config_key = 'fees';
    
    -- Check job is available
    SELECT status INTO v_job_status FROM jobs WHERE id = p_job_id;
    
    IF v_job_status != 'matched' AND v_job_status != 'posted' THEN
        RAISE EXCEPTION 'Job is no longer available';
    END IF;
    
    -- Create booking atomically
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
    
    -- Update job status
    UPDATE jobs SET status = 'accepted', updated_at = NOW()
    WHERE id = p_job_id;
    
    -- Reject other matches
    UPDATE job_matches SET status = 'expired' 
    WHERE job_id = p_job_id AND worker_id != p_worker_id;
    
    -- Add timeline event
    INSERT INTO booking_timeline (booking_id, event, details)
    VALUES (v_booking_id, 'accepted', 'Worker accepted the job');
    
    RETURN v_booking_id;
END;
$$ LANGUAGE plpgsql;

-- Function to process payment
CREATE OR REPLACE FUNCTION process_payment(
    p_booking_id UUID,
    p_payment_method_id UUID
) RETURNS UUID AS $$
DECLARE
    v_payment_id UUID;
    v_booking_status booking_status;
BEGIN
    -- Check booking is completed
    SELECT status INTO v_booking_status FROM bookings WHERE id = p_booking_id;
    
    IF v_booking_status != 'completed' THEN
        RAISE EXCEPTION 'Booking must be completed before payment';
    END IF;
    
    -- Check if already paid
    IF EXISTS (SELECT 1 FROM payments WHERE booking_id = p_booking_id AND status = 'completed') THEN
        RAISE EXCEPTION 'Payment already completed for this booking';
    END IF;
    
    -- Create payment
    INSERT INTO payments (
        booking_id, client_id, worker_id, payment_method_id,
        amount_etb, service_fee_etb, worker_payout_etb,
        status
    )
    SELECT 
        b.id, b.client_id, b.worker_id, p_payment_method_id,
        b.fixed_price_etb, b.platform_fee_etb, b.worker_payout_etb,
        'pending'
    FROM bookings b
    WHERE b.id = p_booking_id
    RETURNING payments.id INTO v_payment_id;
    
    -- Update booking status
    UPDATE bookings SET status = 'paid', updated_at = NOW()
    WHERE id = p_booking_id;
    
    -- Update job status
    UPDATE jobs SET status = 'paid', updated_at = NOW()
    FROM bookings b WHERE b.job_id = jobs.id AND b.id = p_booking_id;
    
    RETURN v_payment_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 18. TRIGGERS
-- ============================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_client_profiles_updated_at BEFORE UPDATE ON client_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_worker_profiles_updated_at BEFORE UPDATE ON worker_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_jobs_updated_at BEFORE UPDATE ON jobs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_disputes_updated_at BEFORE UPDATE ON disputes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_ratings_updated_at BEFORE UPDATE ON ratings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-calculate trust score after relevant changes
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

-- Log all admin actions
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

-- ============================================
-- 19. DATA RETENTION & ARCHIVING
-- ============================================

-- Archive old SMS logs (can be scheduled with pg_cron)
CREATE OR REPLACE FUNCTION archive_old_sms_logs()
RETURNS void AS $$
BEGIN
    -- Create archive table if not exists
    CREATE TABLE IF NOT EXISTS sms_logs_archive (LIKE sms_logs INCLUDING ALL);
    
    -- Move old records
    INSERT INTO sms_logs_archive 
    SELECT * FROM sms_logs 
    WHERE created_at < NOW() - INTERVAL '90 days';
    
    -- Delete from main table
    DELETE FROM sms_logs 
    WHERE created_at < NOW() - INTERVAL '90 days';
    
    -- Also archive old OTP records
    DELETE FROM otp_codes 
    WHERE created_at < NOW() - INTERVAL '30 days';
    
    DELETE FROM otp_rate_limits 
    WHERE window_start < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- Archive completed jobs older than 3 years
CREATE OR REPLACE FUNCTION archive_old_jobs()
RETURNS void AS $$
BEGIN
    UPDATE jobs 
    SET status = 'archived' 
    WHERE created_at < NOW() - INTERVAL '3 years'
      AND status IN ('completed', 'paid', 'cancelled');
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 20. SEED DATA - SMS TEMPLATES
-- ============================================

INSERT INTO sms_templates (template_key, template_name, content_amharic, content_english, variables) VALUES
('otp_login', 'OTP Login', 
 'Habesha Fresh: የመግቢያ ኮድዎ {otp} ነው። ከ5 ደቂቃ በኋላ ያበቃል።', 
 'Habesha Fresh: Your login code is {otp}. Expires in 5 minutes.',
 ARRAY['otp']),
('otp_registration', 'OTP Registration',
 'Habesha Fresh: እንኳን ደህና መጡ! የምዝገባ ኮድዎ {otp} ነው።',
 'Habesha Fresh: Welcome! Your registration code is {otp}.',
 ARRAY['otp']),
('job_match', 'Job Match Notification',
 'Habesha Fresh: Job {job_id} | {trade} | {job_type} | {price} ETB | {area}. Client: {trust_level}. Reply ACCEPT {job_id} or REJECT {job_id}',
 'Habesha Fresh: Job {job_id} | {trade} | {job_type} | {price} ETB | {area}. Client: {trust_level}. Reply ACCEPT {job_id} or REJECT {job_id}',
 ARRAY['job_id', 'trade', 'job_type', 'price', 'area', 'trust_level']),
('job_accepted', 'Job Accepted Confirmation',
 'You accepted job {job_id}. Client: {client_name}, {client_phone}, {address}. Date: {date} {time}. Platform not liable for work quality/disputes.', 
 'You accepted job {job_id}. Client: {client_name}, {client_phone}, {address}. Date: {date} {time}. Platform not liable for work quality/disputes.',
 ARRAY['job_id', 'client_name', 'client_phone', 'address', 'date', 'time']),
('reminder', 'Job Reminder',
 'Reminder: Job {job_id} in 1 hour. {role}: {name}, {phone}.',
 'Reminder: Job {job_id} in 1 hour. {role}: {name}, {phone}.',
 ARRAY['job_id', 'role', 'name', 'phone']),
('payment_receipt', 'Payment Receipt',
 'Payment received: {amount} ETB for job {job_id}. Receipt: {receipt_url}. Thank you!',
 'Payment received: {amount} ETB for job {job_id}. Receipt: {receipt_url}. Thank you!',
 ARRAY['amount', 'job_id', 'receipt_url']),
('verification_approved', 'Verification Approved',
 'Congratulations! Your {trade} verification has been approved. You can now receive job matches.',
 'Congratulations! Your {trade} verification has been approved. You can now receive job matches.',
 ARRAY['trade']),
('verification_revoked', 'Verification Revoked',
 'Your {trade} verification has been revoked. Reason: {reason}. Contact support for more information.',
 'Your {trade} verification has been revoked. Reason: {reason}. Contact support for more information.',
 ARRAY['trade', 'reason']);

-- ============================================
-- 21. ENCRYPTION HELPER FUNCTIONS
-- ============================================

-- Function to encrypt sensitive data (government ID, etc.)
CREATE OR REPLACE FUNCTION encrypt_sensitive_data(p_data TEXT, p_key TEXT DEFAULT current_setting('app.encryption_key'))
RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(p_data, p_key);
END;
$$ LANGUAGE plpgsql;

-- Function to decrypt sensitive data
CREATE OR REPLACE FUNCTION decrypt_sensitive_data(p_encrypted BYTEA, p_key TEXT DEFAULT current_setting('app.encryption_key'))
RETURNS TEXT AS $$
BEGIN
    RETURN pgp_sym_decrypt(p_encrypted, p_key);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 22. GRANTS & PERMISSIONS
-- ============================================

-- Create application role
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'habesha_connect_app') THEN
        CREATE ROLE habesha_connect_app WITH LOGIN PASSWORD 'change_me_in_production';
    END IF;
END
$$;

-- Grant permissions
GRANT CONNECT ON DATABASE habesha_connect TO habesha_connect_app;
GRANT USAGE ON SCHEMA public TO habesha_connect_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO habesha_connect_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO habesha_connect_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO habesha_connect_app;

-- ============================================
-- COMPLETE
-- ============================================
COMMENT ON DATABASE habesha_connect IS 'Habesha Fresh Platform Database - v2.0';