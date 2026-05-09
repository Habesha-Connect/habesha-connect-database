#!/bin/bash

# Load environment variables
source ../.env 2>/dev/null || source .env 2>/dev/null

echo "Running migrations..."

for migration in migrations/*.sql; do
    echo "Applying: $migration"
    psql -h ${DB_HOST:-localhost} \
         -p ${DB_PORT:-5432} \
         -U ${DB_USER:-habesha_connect_app} \
         -d ${DB_NAME:-habesha_connect} \
         -f "$migration"
    
    if [ $? -ne 0 ]; then
        echo "Migration failed: $migration"
        exit 1
    fi
done

echo "All migrations applied successfully"
