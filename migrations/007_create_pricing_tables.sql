-- Migration 007: Create Fixed Pricing Tables
-- Description: Job type catalog with fixed prices
-- Dependencies: 003 (users table)

CREATE TABLE fixed_price_jobs (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trade               trade_type NOT NULL,
    job_name            VARCHAR(200) NOT NULL,
    description         TEXT,
    price_etb           DECIMAL(10,2) NOT NULL CHECK (price_etb > 0),
    estimated_duration  VARCHAR(50),
    includes            TEXT[] DEFAULT '{}',
    excludes            TEXT[] DEFAULT '{}',
    is_active           BOOLEAN DEFAULT TRUE,
    created_by          UUID REFERENCES users(id),
    updated_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Price change audit trail
CREATE TABLE fixed_price_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    price_id        UUID REFERENCES fixed_price_jobs(id) ON DELETE CASCADE,
    old_price_etb   DECIMAL(10,2),
    new_price_etb   DECIMAL(10,2),
    changed_by      UUID REFERENCES users(id),
    change_reason   TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);