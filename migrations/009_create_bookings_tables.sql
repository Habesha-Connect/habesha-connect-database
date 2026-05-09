-- Migration 009: Create Booking Tables
-- Description: Booking management and timeline tracking
-- Dependencies: 003, 004, 005, 008

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

-- Booking event timeline
CREATE TABLE booking_timeline (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id      UUID REFERENCES bookings(id) ON DELETE CASCADE,
    event           VARCHAR(50) NOT NULL,
    details         TEXT,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);