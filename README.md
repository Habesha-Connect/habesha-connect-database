# Habesha Connect - Database

PostgreSQL database schema, migrations, and seed data for the Habesha Connect platform.

[![Built in Ethiopia](https://img.shields.io/badge/Built%20in-Ethiopia-brightgreen)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue)]()
[![Docker](https://img.shields.io/badge/Docker-Ready-blue)]()

---

## Overview

This repository contains the complete database design for Habesha Connect, a platform connecting Ethiopian homeowners with verified informal workers including electricians, plumbers, carpenters, masons, painters, and cleaners.

The schema supports:
- User authentication via phone OTP (TeleRivet SMS integration)
- Client and worker profiles with verification systems
- Worker in-person verification tracking (practical and theoretical testing)
- Fixed price job posting and worker matching
- Booking and payment processing
- Rating, review, and dispute resolution
- Admin portal management
- Comprehensive audit logging
- SMS notification tracking and cost monitoring

---

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Or PostgreSQL 16+ installed locally

### Option 1: Docker (Recommended)

```bash
# Clone the repository
git clone https://github.com/Habesha-Connect/habesha-connect-database.git
cd habesha-connect-database

# Start PostgreSQL container
docker compose up -d

# Wait for PostgreSQL to be ready (5-10 seconds)
sleep 5

# Apply the complete schema
docker compose exec -T db psql -U habesha_connect_app -d habesha_connect < schemas/habesha-connect-v2.0.sql

# Verify installation
docker compose exec db psql -U habesha_connect_app -d habesha_connect -c "\dt"
```

### Option 2: Local PostgreSQL

```bash
# Install PostgreSQL
sudo apt install postgresql postgresql-client

# Start the service
sudo systemctl start postgresql

# Create database and user
sudo -u postgres psql -c "CREATE USER habesha_connect_app WITH PASSWORD 'your_password';"
sudo -u postgres psql -c "CREATE DATABASE habesha_connect OWNER habesha_connect_app;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE habesha_connect TO habesha_connect_app;"

# Apply schema
psql -h localhost -U habesha_connect_app -d habesha_connect -f schemas/habesha-connect-v2.0.sql

# Verify
psql -h localhost -U habesha_connect_app -d habesha_connect -c "\dt"
```

---

## Database Specifications

| Specification | Details |
|---------------|---------|
| **Database** | PostgreSQL 16+ |
| **Schema Version** | 2.0.0 |
| **Tables** | 41 |
| **Views** | 5 |
| **Custom Functions** | 12 |
| **Triggers** | 10+ |
| **Indexes** | 50+ |
| **Enum Types** | 19 |
| **Character Set** | UTF-8 |
| **Primary Languages** | Amharic + English |

---

## Connection Details

### Docker (Default)
```
Host: localhost
Port: 5432
Database: habesha_connect
User: habesha_connect_app
Password: dev_password_123
```

### Connection String
```
postgresql://habesha_connect_app:dev_password_123@localhost:5432/habesha_connect
```

---

## Schema Architecture

### Entity Relationship Overview

```
users
├── client_profiles
│   ├── client_verification_documents
│   ├── client_payment_methods
│   ├── client_trust_scores
│   └── client_flags
├── worker_profiles
│   ├── worker_trades
│   │   └── verification_sessions
│   └── (bookings)
└── verifier_profiles

jobs
├── job_photos
├── job_matches
└── bookings
    ├── booking_timeline
    ├── payments
    │   ├── receipts
    │   └── payment_gateway_logs
    ├── ratings
    │   └── rating_reports
    └── disputes
        ├── dispute_evidence
        └── dispute_timeline
```

### Core Tables

**Users & Authentication (9 tables)**
- `users` - Platform users with roles (client, worker, verifier, admin)
- `otp_codes` - OTP tracking with TeleRivet SMS integration
- `otp_rate_limits` - Rate limiting for OTP requests
- `account_lockouts` - Brute force protection
- `refresh_tokens` - JWT refresh token management
- `user_sessions` - Active session tracking
- `terms_acceptance` - Terms acceptance records
- `terms_versions` - Terms version history
- `admin_mfa` - Admin multi-factor authentication

**Client System (5 tables)**
- `client_profiles` - Client profiles with trust scores
- `client_verification_documents` - Document verification
- `client_payment_methods` - Saved payment methods
- `client_trust_scores` - Detailed trust score breakdown
- `client_flags` - Client incident tracking

**Worker System (3 tables)**
- `worker_profiles` - Worker profiles with availability
- `worker_trades` - Worker trade specializations (many-to-many)
- `verifier_profiles` - Vocational teacher profiles

**Verification System (1 table)**
- `verification_sessions` - In-person testing sessions with practical and theoretical scores

**Pricing System (2 tables)**
- `fixed_price_jobs` - Job type catalog with fixed pricing
- `fixed_price_history` - Price change audit trail

**Job System (3 tables)**
- `jobs` - Job postings with location and scheduling
- `job_photos` - Job site photo uploads
- `job_matches` - Worker matching and notification tracking

**Booking System (2 tables)**
- `bookings` - Confirmed job bookings with fee breakdown
- `booking_timeline` - Booking event history

**Payment System (3 tables)**
- `payments` - Payment transactions with gateway tracking
- `receipts` - Payment receipts with download URLs
- `payment_gateway_logs` - Gateway interaction logs

**Rating System (2 tables)**
- `ratings` - Star ratings with aspect-level feedback
- `rating_reports` - Reported reviews

**Dispute System (3 tables)**
- `disputes` - Dispute filings with claims
- `dispute_evidence` - Evidence uploads
- `dispute_timeline` - Dispute event history

**Notification System (5 tables)**
- `sms_logs` - SMS delivery tracking
- `sms_cost_tracking` - SMS cost monitoring
- `sms_templates` - Multi-language SMS templates
- `notification_preferences` - User notification settings
- `in_app_notifications` - In-app notification records

**Admin System (2 tables)**
- `admin_audit_logs` - Admin action logging
- `system_config` - Platform configuration storage

**Reports (1 table)**
- `user_reports` - User-to-user reporting system

---

## Views

### worker_match_scores
Worker ranking view used by the job matching algorithm. Calculates a composite score based on average rating, completed jobs, dispute count, experience, and response time.

### client_trust_overview
Aggregated client trust information including verification status, trust scores, payment reliability, active flags, and critical flags.

### payment_summary
Financial reporting view aggregating payments by month and gateway with totals, fees, and unique user counts.

### active_jobs_view
Dashboard view showing all active jobs with client and worker details, trust levels, and hours waiting.

### sms_delivery_stats
Analytics view for SMS delivery performance by day, notification type, and delivery status.

---

## Key Functions

### Business Logic Functions

| Function | Description |
|----------|-------------|
| `calculate_client_trust_score(client_id)` | Dynamically calculates and updates client trust score based on verification, payment speed, communication, cancellations, and disputes |
| `match_job_to_workers(job_id)` | Matches available verified workers to a job based on trade, location, and match score. Returns top 10 matches. |
| `accept_job_booking(job_id, worker_id, worker_trade_id)` | Atomically creates a booking when a worker accepts a job. Calculates platform fees and worker payout. |
| `process_payment(booking_id, payment_method_id)` | Processes payment for a completed booking with validation for existing payments. |

### Utility Functions

| Function | Description |
|----------|-------------|
| `encrypt_sensitive_data(data, key)` | Encrypts sensitive data (government IDs) using pgcrypto |
| `decrypt_sensitive_data(encrypted, key)` | Decrypts sensitive data |
| `archive_old_sms_logs()` | Archives SMS logs older than 90 days and cleans up expired OTP records |
| `archive_old_jobs()` | Archives completed jobs older than 3 years |

### Trigger Functions

| Function | Description |
|----------|-------------|
| `update_updated_at_column()` | Automatically updates the `updated_at` timestamp on row modification |
| `trigger_trust_score_update()` | Recalculates client trust score when verification status or payment methods change |
| `log_admin_action()` | Logs all admin actions to the audit log |

---

## Enum Types

| Enum | Values |
|------|--------|
| `user_role` | client, worker, verifier, admin |
| `trade_type` | electrician, plumber, carpenter, mason, painter, cleaner, other |
| `verification_status` | unverified, pending, in_progress, verified, failed, revoked |
| `job_status` | posted, matched, accepted, rejected, in_progress, completed, paid, disputed, cancelled, expired, archived |
| `payment_status` | pending, processing, completed, failed, refunded |
| `dispute_status` | open, under_review, resolved, closed |
| `booking_status` | pending, accepted, rejected, in_progress, completed, cancelled |
| `trust_level` | trusted, standard, caution, high_risk |
| `notification_type` | otp, job_match, job_accepted, job_rejected, reminder, payment_confirmation, payment_receipt, rating_request, dispute_update, verification_update, system, welcome |
| `sms_status` | queued, sent, delivered, failed, bounced |

---

## SMS Templates

| Template Key | Purpose |
|-------------|---------|
| `otp_login` | Login OTP codes |
| `otp_registration` | Registration OTP codes |
| `otp_payment` | Payment confirmation OTP |
| `job_match` | New job notifications to workers |
| `job_accepted_worker` | Booking confirmation to workers |
| `job_accepted_client` | Booking confirmation to clients |
| `reminder` | 1-hour before job reminders |
| `payment_confirmation` | Payment receipt notifications |
| `rating_request` | Post-job rating requests |
| `verification_approved` | Verification approval notifications |
| `verification_revoked` | Verification revocation notices |
| `verification_scheduled` | Test scheduling notifications |
| `dispute_filed` | Dispute filing confirmations |
| `welcome_client` | New client welcome messages |
| `welcome_worker` | New worker welcome messages |

All templates support both Amharic and English with variable substitution.

---

## System Configuration

The `system_config` table stores platform-wide settings:

| Config Key | Description | Default Values |
|------------|-------------|----------------|
| `fees` | Platform fee structure | 10% fee, min 50 ETB, max 500 ETB |
| `matching` | Job matching parameters | 10 workers max, 15km radius, 24hr expiry |
| `disputes` | Dispute resolution settings | 48hr filing window, 7-day auto-resolve |
| `notifications` | Notification timing | 60min job reminder, 24hr rating request |
| `otp` | OTP security settings | 3 per hour, 5min expiry, 3 max attempts |

---

## File Structure

```
habesha-connect-database/
├── migrations/                    # Sequential migration files (21 files)
│   ├── 001_create_extensions.sql
│   ├── 002_create_enums.sql
│   ├── 003_create_users_tables.sql
│   ├── 004_create_client_tables.sql
│   ├── 005_create_worker_tables.sql
│   ├── 006_create_verification_tables.sql
│   ├── 007_create_pricing_tables.sql
│   ├── 008_create_jobs_tables.sql
│   ├── 009_create_bookings_tables.sql
│   ├── 010_create_payments_tables.sql
│   ├── 011_create_ratings_tables.sql
│   ├── 012_create_disputes_tables.sql
│   ├── 013_create_notifications_tables.sql
│   ├── 014_create_reports_tables.sql
│   ├── 015_create_admin_tables.sql
│   ├── 016_create_indexes.sql
│   ├── 017_create_views.sql
│   ├── 018_create_functions.sql
│   ├── 019_create_triggers.sql
│   ├── 020_create_seed_data.sql
│   └── 021_create_grants.sql
├── seeds/                         # Seed data by environment
│   ├── development/
│   ├── staging/
│   └── production/
├── schemas/                       # Complete schema reference files
│   └── habesha-connect-v2.0.sql
├── scripts/                       # Database management scripts
│   ├── create-database.sh
│   ├── migrate.sh
│   ├── rollback.sh
│   ├── seed.sh
│   ├── backup.sh
│   └── restore.sh
├── docs/                          # Schema documentation
│   ├── schema-diagram.md
│   ├── entity-relationships.md
│   ├── indexing-strategy.md
│   └── migration-guide.md
├── .github/                       # CI/CD workflows
├── docker-compose.yml
├── .env.example
├── .gitignore
├── CONTRIBUTING.md
├── COMMIT_CONVENTIONS.md
└── README.md
```

---

## Common Commands

### Docker Management

```bash
# Start database
docker compose up -d

# Stop database
docker compose down

# View logs
docker compose logs db

# Restart database
docker compose restart

# Connect to PostgreSQL
docker compose exec db psql -U habesha_connect_app -d habesha_connect

# Reset everything (deletes all data)
docker compose down -v
docker compose up -d
docker compose exec -T db psql -U habesha_connect_app -d habesha_connect < schemas/habesha-connect-v2.0.sql
```

### Schema Management

```bash
# Apply complete schema
docker compose exec -T db psql -U habesha_connect_app -d habesha_connect < schemas/habesha-connect-v2.0.sql

# Apply individual migration files
for file in migrations/*.sql; do
    docker compose exec -T db psql -U habesha_connect_app -d habesha_connect < "$file"
done

# Create backup
docker compose exec db pg_dump -U habesha_connect_app habesha_connect > backup.sql

# Restore from backup
docker compose exec -T db psql -U habesha_connect_app -d habesha_connect < backup.sql
```

### Useful Queries

```bash
# List all tables
docker compose exec db psql -U habesha_connect_app -d habesha_connect -c "\dt"

# Count tables
docker compose exec db psql -U habesha_connect_app -d habesha_connect -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';"

# List views
docker compose exec db psql -U habesha_connect_app -d habesha_connect -c "SELECT table_name FROM information_schema.views WHERE table_schema = 'public';"

# List enum types
docker compose exec db psql -U habesha_connect_app -d habesha_connect -c "SELECT typname FROM pg_type WHERE typtype = 'e' ORDER BY typname;"

# View system configuration
docker compose exec db psql -U habesha_connect_app -d habesha_connect -c "SELECT config_key, description, config_value FROM system_config;"

# View SMS templates
docker compose exec db psql -U habesha_connect_app -d habesha_connect -c "SELECT template_key, template_name FROM sms_templates;"

# Describe a table
docker compose exec db psql -U habesha_connect_app -d habesha_connect -c "\d users"
```

---

## Development

### Adding New Migrations

1. Create a new file with the next sequential number in `migrations/`
2. Write your SQL with clear comments
3. Test locally before committing
4. Follow our [commit conventions](COMMIT_CONVENTIONS.md)

### Migration Rules

- Never modify existing migration files
- Always create new migrations for changes
- Include descriptive comments
- Test both upgrade and downgrade paths
- Update schema documentation

### Commit Conventions

```
type(schema): description

Types: feat, fix, refactor, perf, docs
Scopes: schema, migrations, seeds, indexes, views, functions
```

---

## Environment Variables

Copy `.env.example` to `.env` and configure:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=habesha_connect
DB_USER=habesha_connect_app
DB_PASSWORD=change_me_in_production
DB_SSL_MODE=disable
ENCRYPTION_KEY=your_encryption_key_here
```

---

## Performance Guidelines

- All foreign keys have corresponding indexes
- Use parameterized queries (never string concatenation)
- Monitor with `EXPLAIN ANALYZE` for complex queries
- Regular `VACUUM ANALYZE` maintenance
- Use `pg_stat_statements` for query performance monitoring

---

## Security

- Sensitive data encrypted at rest using pgcrypto
- Government IDs stored as encrypted BYTEA
- Application user has least privilege access
- Passwords never stored in repository
- Regular dependency updates via Dependabot

---

## Contributing

Please read our [Contributing Guide](CONTRIBUTING.md) and [Commit Conventions](COMMIT_CONVENTIONS.md) before submitting pull requests.

### Commit Rules
We follow [Conventional Commits](https://www.conventionalcommits.org/):
```
feat(schema): add new table for feature X
fix(migrations): correct index on jobs table
docs(schema): update entity relationship diagram
```

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Related Repositories

- [habesha-connect-web](https://github.com/Habesha-Connect/habesha-connect-web) - Frontend application
- [habesha-connect-api](https://github.com/Habesha-Connect/habesha-connect-api) - Backend API
- [habesha-connect-docs](https://github.com/Habesha-Connect/habesha-connect-docs) - Documentation
- [habesha-connect-shared](https://github.com/Habesha-Connect/habesha-connect-shared) - Shared types and utilities

---

## Contact

- **Issues:** https://github.com/Habesha-Connect/habesha-connect-database/issues
- **Email:** info@habeshaconnect.com
- **Organization:** https://github.com/Habesha-Connect

---

Built with PostgreSQL for Habesha Connect. Connecting Ethiopian homeowners with verified informal workers.