#!/bin/bash

# Load environment variables
source ../.env 2>/dev/null || source .env 2>/dev/null

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backups/backup_${DB_NAME:-habesha_connect}_${TIMESTAMP}.sql.gz"

echo "Creating backup: $BACKUP_FILE"

pg_dump -h ${DB_HOST:-localhost} \
        -p ${DB_PORT:-5432} \
        -U ${DB_USER:-habesha_connect_app} \
        -d ${DB_NAME:-habesha_connect} \
        | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Backup created successfully: $BACKUP_FILE"
else
    echo "Backup failed"
    exit 1
fi
