-- Migration 002: Create Enum Types
-- Description: Define all custom enum types for the platform
-- Dependencies: None

-- User roles
CREATE TYPE user_role AS ENUM ('client', 'worker', 'verifier', 'admin');

-- Worker trade categories
CREATE TYPE trade_type AS ENUM (
    'electrician', 'plumber', 'carpenter', 'mason', 
    'painter', 'cleaner', 'other'
);

-- Verification status lifecycle
CREATE TYPE verification_status AS ENUM (
    'unverified', 'pending', 'in_progress', 'verified', 'failed', 'revoked'
);

-- Test results for verification
CREATE TYPE test_result AS ENUM ('pass', 'fail');

-- Job lifecycle status
CREATE TYPE job_status AS ENUM (
    'posted', 'matched', 'accepted', 'rejected', 'in_progress', 
    'completed', 'paid', 'disputed', 'cancelled', 'expired', 'archived'
);

-- Payment processing status
CREATE TYPE payment_status AS ENUM (
    'pending', 'processing', 'completed', 'failed', 'refunded'
);

-- Dispute resolution status
CREATE TYPE dispute_status AS ENUM ('open', 'under_review', 'resolved', 'closed');

-- Who filed the dispute
CREATE TYPE dispute_filed_by AS ENUM ('client', 'worker');

-- Language preferences
CREATE TYPE language_preference AS ENUM ('amharic', 'english');

-- Notification categories
CREATE TYPE notification_type AS ENUM (
    'otp', 'job_match', 'job_accepted', 'job_rejected', 'reminder', 
    'payment_confirmation', 'payment_receipt', 'rating_request', 
    'dispute_update', 'verification_update', 'system', 'welcome'
);

-- SMS delivery status
CREATE TYPE sms_status AS ENUM ('queued', 'sent', 'delivered', 'failed', 'bounced');

-- OTP purpose types
CREATE TYPE otp_purpose AS ENUM (
    'login', 'registration', 'payment_confirmation', 'admin_mfa', 'phone_verification'
);

-- Client flag categories
CREATE TYPE flag_type AS ENUM (
    'payment_issue', 'fake_job', 'harassment', 'no_show', 
    'property_damage_threat', 'inappropriate_behavior', 'other'
);

-- Flag severity levels
CREATE TYPE flag_severity AS ENUM ('low', 'medium', 'high', 'critical');

-- Flag resolution status
CREATE TYPE flag_status AS ENUM ('active', 'resolved', 'dismissed');

-- Verification document types
CREATE TYPE document_type AS ENUM (
    'id_card', 'utility_bill', 'property_deed', 'rental_agreement', 'selfie_with_id'
);

-- Payment method types
CREATE TYPE payment_method_type AS ENUM ('telebirr', 'chapa', 'bank_transfer');

-- Client trust levels
CREATE TYPE trust_level AS ENUM ('trusted', 'standard', 'caution', 'high_risk');

-- Booking lifecycle status
CREATE TYPE booking_status AS ENUM (
    'pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled'
);