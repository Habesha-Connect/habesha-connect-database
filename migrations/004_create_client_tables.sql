-- Migration 004: Create Client Profile Tables
-- Description: Client profiles, verification, payment methods, and trust system
-- Dependencies: 003 (users table)

-- Client profiles with trust system
CREATE TABLE client_profiles (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    verification_status     verification_status DEFAULT 'unverified',
    trust_level             trust_level DEFAULT 'standard',
    trust_score             DECIMAL(3,2) DEFAULT 5.00 CHECK (trust_score BETWEEN 0.00 AND 10.00),
    id_type                 VARCHAR(50),
    id_number_hash          VARCHAR(64),
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
    account_identifier_hash VARCHAR(64),
    is_verified         BOOLEAN DEFAULT FALSE,
    is_default          BOOLEAN DEFAULT FALSE,
    verification_method VARCHAR(50),
    verification_code   VARCHAR(10),
    verified_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Client trust score breakdown
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