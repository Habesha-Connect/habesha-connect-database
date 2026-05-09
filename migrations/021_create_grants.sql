-- Migration 021: Create Database Grants & Permissions
-- Description: Application role and permission setup
-- Dependencies: All previous migrations

-- Create application role if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'habesha_connect_app') THEN
        CREATE ROLE habesha_connect_app WITH LOGIN PASSWORD 'change_me_in_production';
    END IF;
END
$$;

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO habesha_connect_app;

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO habesha_connect_app;

-- Grant sequence permissions
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO habesha_connect_app;

-- Grant function execution permissions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO habesha_connect_app;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO habesha_connect_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT USAGE ON SEQUENCES TO habesha_connect_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT EXECUTE ON FUNCTIONS TO habesha_connect_app;

-- Add database comment
COMMENT ON DATABASE habesha_connect IS 'Habesha Connect Platform Database - v2.0';