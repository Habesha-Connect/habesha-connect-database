-- Migration 012: Create Dispute Resolution Tables
-- Description: Dispute filing, evidence, and resolution tracking
-- Dependencies: 003, 009

CREATE TABLE disputes (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id          UUID REFERENCES bookings(id),
    filed_by            dispute_filed_by NOT NULL,
    filed_by_user_id    UUID REFERENCES users(id),
    description         TEXT NOT NULL,
    desired_outcome     TEXT,
    claims              JSONB,
    status              dispute_status DEFAULT 'open',
    admin_id            UUID REFERENCES users(id),
    admin_notes         TEXT,
    resolution          TEXT,
    resolution_type     VARCHAR(50),
    trust_score_impact  DECIMAL(3,2),
    resolved_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Dispute evidence files
CREATE TABLE dispute_evidence (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dispute_id      UUID REFERENCES disputes(id) ON DELETE CASCADE,
    evidence_type   VARCHAR(50) NOT NULL,
    file_url        TEXT NOT NULL,
    thumbnail_url   TEXT,
    description     TEXT,
    uploaded_by     UUID REFERENCES users(id),
    uploaded_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Dispute event timeline
CREATE TABLE dispute_timeline (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dispute_id      UUID REFERENCES disputes(id) ON DELETE CASCADE,
    event           VARCHAR(50) NOT NULL,
    details         TEXT,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);