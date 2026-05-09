#!/bin/bash

# Load environment variables
source ../.env 2>/dev/null || source .env 2>/dev/null

# Create database
psql -h ${DB_HOST:-localhost} \
     -p ${DB_PORT:-5432} \
     -U postgres \
     -c "CREATE DATABASE ${DB_NAME:-habesha_connect};"

# Create application user
psql -h ${DB_HOST:-localhost} \
     -p ${DB_PORT:-5432} \
     -U postgres \
     -c "CREATE USER ${DB_USER:-habesha_connect_app} WITH PASSWORD '${DB_PASSWORD}';"

# Grant permissions
psql -h ${DB_HOST:-localhost} \
     -p ${DB_PORT:-5432} \
     -U postgres \
     -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME:-habesha_connect} TO ${DB_USER:-habesha_connect_app};"

echo "Database and user created successfully"
