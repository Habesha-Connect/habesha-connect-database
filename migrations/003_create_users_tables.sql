-- Migration 003: Create Users & Authentication Tables
-- Description: Core user management and authentication tables
-- Dependencies: 001 (extensions), 002 (enums)

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

-- OTP Codes with TeleRivet tracking
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
    window_type     VARCHAR(20) DEFAULT 'hourly',
    CONSTRAINT unique_phone_window UNIQUE (phone_number, window_start, window_type)
);

-- Account Lockouts for brute force protection
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

-- Terms versions history
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

-- Refresh tokens for JWT
CREATE TABLE refresh_tokens (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    token_hash      VARCHAR(64) UNIQUE NOT NULL,
    expires_at      TIMESTAMPTZ NOT NULL,
    is_revoked      BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- User sessions tracking
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