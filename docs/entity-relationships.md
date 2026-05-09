# Entity Relationships

## Core Relationships

### Users
- One user has one role (client, worker, verifier, admin)
- One user can have one client_profile (if role is client)
- One user can have one worker_profile (if role is worker)
- One user can have one verifier_profile (if role is verifier)

### Client Flow
- Client (users) -> client_profiles -> client_trust_scores
- Client -> client_verification_documents
- Client -> client_payment_methods
- Client -> client_flags

### Worker Flow
- Worker (users) -> worker_profiles -> worker_trades
- Worker -> verification_sessions (via worker_trades)
- Verification sessions -> verifier_profiles

### Job Flow
- Client -> jobs -> job_matches -> worker_trades -> worker_profiles
- Job -> bookings -> payments -> receipts
- Booking -> ratings
- Booking -> disputes

[Continue with complete relationship documentation]
