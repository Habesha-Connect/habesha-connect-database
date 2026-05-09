# Habesha Connect - Database

PostgreSQL database schema, migrations, and seed data for the Habesha Connect platform.

## Overview

This repository contains the complete database design for Habesha Connect, a platform connecting Ethiopian homeowners with verified informal workers. The schema supports:

- User authentication via phone OTP (TeleRivet SMS integration)
- Client and worker profiles with verification systems
- Worker in-person verification tracking (practical and theoretical testing)
- Fixed price job posting and matching
- Booking and payment processing
- Rating, review, and dispute resolution
- Admin portal management
- Comprehensive audit logging
- SMS notification tracking and cost monitoring

## Database Specifications

| Specification | Details |
|---------------|---------|
| **Database** | PostgreSQL 16+ |
| **Schema Version** | 2.0.0 |
| **Tables** | 35+ |
| **Views** | 8 |
| **Functions** | 10+ |
| **Triggers** | 12+ |
| **Indexes** | 50+ |
| **Character Set** | UTF-8 |
| **Primary Language** | Amharic + English |

## Quick Start

### Prerequisites
- PostgreSQL 16 or higher
- Docker (optional, for containerized development)

### Option 1: Local Setup

```bash
# Create database
createdb habesha_connect

# Run migrations
./scripts/migrate.sh

# Seed development data
./scripts/seed.sh development

# Verify setup
psql -d habesha_connect -c "\dt"