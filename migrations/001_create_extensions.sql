-- Migration 001: Create Extensions
-- Description: Enable required PostgreSQL extensions
-- Dependencies: None

-- UUID generation support
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Cryptographic functions for encryption
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Verify installations
DO $$
BEGIN
    RAISE NOTICE 'Extensions created successfully';
END $$;