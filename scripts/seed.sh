#!/bin/bash

ENVIRONMENT=${1:-development}

# Load environment variables
source ../.env 2>/dev/null || source .env 2>/dev/null

echo "Seeding database for environment: $ENVIRONMENT"

for seed in seeds/$ENVIRONMENT/*.sql; do
    echo "Applying: $seed"
    psql -h ${DB_HOST:-localhost} \
         -p ${DB_PORT:-5432} \
         -U ${DB_USER:-habesha_connect_app} \
         -d ${DB_NAME:-habesha_connect} \
         -f "$seed"
    
    if [ $? -ne 0 ]; then
        echo "Seed failed: $seed"
        exit 1
    fi
done

echo "Seed data applied successfully"
