-- Migration 014: Create User Reports Table
-- Description: User-to-user reporting system
-- Dependencies: 003, 008, 009

CREATE TABLE user_reports (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id         UUID REFERENCES users(id),
    reported_user_id    UUID REFERENCES users(id),
    job_id              UUID REFERENCES jobs(id),
    booking_id          UUID REFERENCES bookings(id),
    reason              TEXT NOT NULL,
    description         TEXT,
    evidence_urls       TEXT[] DEFAULT '{}',
    status              VARCHAR(20) DEFAULT 'pending',
    admin_id            UUID REFERENCES users(id),
    admin_notes         TEXT,
    action_taken        VARCHAR(100),
    reviewed_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);