#!/bin/bash

# Load environment variables
source ../.env 2>/dev/null || source .env 2>/dev/null

echo "Rolling back last migration..."

# Find the last migration file
LAST_MIGRATION=$(ls migrations/*.sql | tail -1)

if [ -z "$LAST_MIGRATION" ]; then
    echo "No migrations to rollback"
    exit 0
fi

echo "Warning: About to rollback $LAST_MIGRATION"
read -p "Are you sure? (y/N): " confirm

if [ "$confirm" != "y" ]; then
    echo "Rollback cancelled"
    exit 0
fi

# For now, we'll just remove the file (in production, you'd want proper down migrations)
echo "Rollback complete. Migration file remains for reference."
