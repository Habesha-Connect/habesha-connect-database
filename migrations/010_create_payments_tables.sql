-- Migration 010: Create Payment Tables
-- Description: Payment processing and receipt generation
-- Dependencies: 003, 004, 005, 009

CREATE TABLE payments (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id              UUID REFERENCES bookings(id),
    client_id               UUID REFERENCES users(id),
    worker_id               UUID REFERENCES worker_profiles(id),
    payment_method_id       UUID REFERENCES client_payment_methods(id),
    amount_etb              DECIMAL(10,2) NOT NULL,
    service_fee_etb         DECIMAL(10,2) NOT NULL,
    worker_payout_etb       DECIMAL(10,2) NOT NULL,
    gateway                 VARCHAR(50),
    gateway_transaction_id  VARCHAR(255),
    gateway_reference       VARCHAR(255),
    status                  payment_status DEFAULT 'pending',
    payment_instructions    JSONB,
    completed_at            TIMESTAMPTZ,
    expires_at              TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 minutes'),
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- Payment receipts
CREATE TABLE receipts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id      UUID REFERENCES payments(id),
    receipt_number  VARCHAR(50) UNIQUE NOT NULL,
    client_name     VARCHAR(100),
    worker_name     VARCHAR(100),
    amount_etb      DECIMAL(10,2),
    service_fee_etb DECIMAL(10,2),
    worker_payout   DECIMAL(10,2),
    receipt_url     TEXT,
    pdf_url         TEXT,
    generated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Payment gateway interaction logs
CREATE TABLE payment_gateway_logs (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id              UUID REFERENCES payments(id),
    gateway                 VARCHAR(50),
    event                   VARCHAR(50),
    request_payload         JSONB,
    response_payload        JSONB,
    status_code             INTEGER,
    success                 BOOLEAN,
    created_at              TIMESTAMPTZ DEFAULT NOW()
);