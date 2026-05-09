-- Migration 005: Create Worker Profile Tables
-- Description: Worker profiles, trades, and verifier profiles
-- Dependencies: 003 (users table)

-- Worker profiles
CREATE TABLE worker_profiles (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    government_id_encrypted BYTEA,
    government_id_hash  VARCHAR(64),
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

-- Worker trades (many-to-many relationship with verification per trade)
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