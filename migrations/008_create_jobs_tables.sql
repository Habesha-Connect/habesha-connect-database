-- Migration 008: Create Jobs & Matching Tables
-- Description: Job postings, photos, and worker matching
-- Dependencies: 003, 004, 007

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
    location_coordinates POINT,
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

-- Job site photos
CREATE TABLE job_photos (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id          UUID REFERENCES jobs(id) ON DELETE CASCADE,
    photo_url       TEXT NOT NULL,
    thumbnail_url   TEXT,
    file_size_bytes INTEGER,
    uploaded_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Worker matching records
CREATE TABLE job_matches (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id          UUID REFERENCES jobs(id) ON DELETE CASCADE,
    worker_id       UUID REFERENCES worker_profiles(id),
    worker_trade_id UUID REFERENCES worker_trades(id),
    match_score     DECIMAL(3,1),
    status          VARCHAR(20) DEFAULT 'pending',
    sms_sent_at     TIMESTAMPTZ,
    sms_status      sms_status DEFAULT 'queued',
    televeret_message_id VARCHAR(255),
    responded_at    TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Add foreign key constraints to client_flags that reference jobs and bookings
ALTER TABLE client_flags 
    ADD CONSTRAINT fk_client_flags_job 
    FOREIGN KEY (job_id) REFERENCES jobs(id);

ALTER TABLE client_flags 
    ADD CONSTRAINT fk_client_flags_booking 
    FOREIGN KEY (booking_id) REFERENCES bookings(id);