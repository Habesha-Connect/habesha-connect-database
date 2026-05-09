-- Migration 006: Create Verification Tables
-- Description: In-person verification sessions for workers
-- Dependencies: 005 (worker tables)

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