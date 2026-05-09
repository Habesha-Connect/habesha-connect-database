-- Migration 011: Create Rating & Review Tables
-- Description: User ratings, reviews, and review reports
-- Dependencies: 003, 009

CREATE TABLE ratings (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id          UUID UNIQUE REFERENCES bookings(id),
    rater_id            UUID REFERENCES users(id),
    rated_user_id       UUID REFERENCES users(id),
    rating              INTEGER CHECK (rating BETWEEN 1 AND 5),
    review_text         TEXT,
    aspects             JSONB,
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

-- Review reports
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