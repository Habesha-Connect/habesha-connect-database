-- Migration 013: Create Notification & SMS Tables
-- Description: SMS logging, templates, and notification system
-- Dependencies: 003

CREATE TABLE sms_logs (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_phone         VARCHAR(15) NOT NULL,
    message_text            TEXT NOT NULL,
    notification_type       notification_type NOT NULL,
    reference_id            UUID,
    reference_type          VARCHAR(50),
    televeret_message_id    VARCHAR(255),
    televeret_status        sms_status DEFAULT 'queued',
    delivery_time_seconds   INTEGER,
    cost_etb                DECIMAL(10,4),
    error_code              VARCHAR(50),
    error_message           TEXT,
    delivered_at            TIMESTAMPTZ,
    created_at              TIMESTAMPTZ DEFAULT NOW()
);

-- SMS cost tracking
CREATE TABLE sms_cost_tracking (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sms_log_id          UUID REFERENCES sms_logs(id),
    phone_number        VARCHAR(15),
    televeret_cost_etb  DECIMAL(10,4),
    currency            VARCHAR(3) DEFAULT 'ETB',
    billed_at           TIMESTAMPTZ DEFAULT NOW()
);

-- SMS templates
CREATE TABLE sms_templates (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_key    VARCHAR(50) UNIQUE NOT NULL,
    template_name   VARCHAR(100) NOT NULL,
    content_amharic TEXT NOT NULL,
    content_english TEXT NOT NULL,
    variables       TEXT[] DEFAULT '{}',
    is_active       BOOLEAN DEFAULT TRUE,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- User notification preferences
CREATE TABLE notification_preferences (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    sms_notifications       BOOLEAN DEFAULT TRUE,
    email_notifications     BOOLEAN DEFAULT FALSE,
    job_matches             BOOLEAN DEFAULT TRUE,
    reminders               BOOLEAN DEFAULT TRUE,
    payment_updates         BOOLEAN DEFAULT TRUE,
    rating_requests         BOOLEAN DEFAULT TRUE,
    dispute_updates         BOOLEAN DEFAULT TRUE,
    marketing               BOOLEAN DEFAULT FALSE,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- In-app notifications
CREATE TABLE in_app_notifications (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    type            notification_type NOT NULL,
    title           VARCHAR(200) NOT NULL,
    message         TEXT NOT NULL,
    data            JSONB,
    is_read         BOOLEAN DEFAULT FALSE,
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);