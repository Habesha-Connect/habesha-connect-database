-- Migration 017: Create Database Views
-- Description: Common query views for matching, reporting, and analytics
-- Dependencies: All table migrations

-- Worker ranking for job matching algorithm
CREATE VIEW worker_match_scores AS
SELECT 
    wp.id as worker_id,
    u.full_name,
    u.phone_number,
    wt.trade,
    wp.city,
    wp.sub_city,
    wp.verification_status,
    AVG(r.rating)::DECIMAL(3,2) as avg_rating,
    COUNT(DISTINCT b.id) as completed_jobs,
    COUNT(DISTINCT d.id) as dispute_count,
    wp.years_of_experience,
    wp.is_available,
    COALESCE(AVG(r.rating), 3.0) * 0.5 + 
    LEAST(COUNT(DISTINCT b.id) * 0.1, 1.0) * 0.3 -
    COUNT(DISTINCT d.id) * 0.2 as match_score,
    CASE WHEN wp.avg_response_time_minutes <= 15 THEN 0.5 ELSE 0 END as response_bonus
FROM worker_profiles wp
JOIN users u ON wp.user_id = u.id
JOIN worker_trades wt ON wp.id = wt.worker_id
LEFT JOIN bookings b ON wp.id = b.worker_id AND b.status IN ('completed', 'paid')
LEFT JOIN ratings r ON b.id = r.booking_id AND r.rated_user_id = u.id
LEFT JOIN disputes d ON b.id = d.booking_id AND d.status IN ('open', 'under_review')
WHERE u.is_active = TRUE 
  AND u.is_suspended = FALSE
  AND wp.verification_status = 'verified'
  AND wt.verification_status = 'verified'
  AND wp.is_available = TRUE
GROUP BY wp.id, u.full_name, u.phone_number, wt.trade, wp.city, 
         wp.sub_city, wp.verification_status, wp.years_of_experience,
         wp.is_available, wp.avg_response_time_minutes;

-- Client trust overview
CREATE VIEW client_trust_overview AS
SELECT 
    cp.id as client_id,
    cp.user_id,
    u.full_name,
    cp.verification_status,
    cp.trust_level,
    cp.trust_score,
    cts.payment_reliability,
    cts.communication_score,
    cp.total_jobs_posted,
    cp.total_jobs_completed,
    cp.total_spent_etb,
    cp.dispute_rate,
    cp.avg_payment_time_hours,
    COUNT(cf.id) FILTER (WHERE cf.status = 'active') as active_flags,
    COUNT(cf.id) FILTER (WHERE cf.severity = 'critical' AND cf.status = 'active') as critical_flags
FROM client_profiles cp
JOIN users u ON cp.user_id = u.id
LEFT JOIN client_trust_scores cts ON cp.id = cts.client_id
LEFT JOIN client_flags cf ON cp.id = cf.client_id
WHERE u.is_active = TRUE
GROUP BY cp.id, cp.user_id, u.full_name, cp.verification_status, cp.trust_level,
         cp.trust_score, cts.payment_reliability, cts.communication_score,
         cp.total_jobs_posted, cp.total_jobs_completed, cp.total_spent_etb,
         cp.dispute_rate, cp.avg_payment_time_hours;

-- Payment summary for financial reports
CREATE VIEW payment_summary AS
SELECT 
    DATE_TRUNC('month', p.completed_at) as month,
    p.gateway,
    COUNT(p.id) as total_payments,
    SUM(p.amount_etb) as total_amount,
    SUM(p.service_fee_etb) as total_service_fees,
    SUM(p.worker_payout_etb) as total_payouts,
    AVG(p.service_fee_etb / NULLIF(p.amount_etb, 0) * 100) as avg_fee_percentage,
    COUNT(DISTINCT p.client_id) as unique_clients,
    COUNT(DISTINCT p.worker_id) as unique_workers
FROM payments p
WHERE p.status = 'completed'
GROUP BY DATE_TRUNC('month', p.completed_at), p.gateway
ORDER BY month DESC;

-- Active jobs dashboard
CREATE VIEW active_jobs_view AS
SELECT 
    j.id as job_id,
    j.trade,
    j.job_type,
    j.description,
    j.preferred_date,
    j.preferred_time,
    j.location_address,
    j.location_city,
    j.fixed_price_etb,
    j.status,
    j.created_at,
    c.full_name as client_name,
    c.phone_number as client_phone,
    cp.trust_level as client_trust_level,
    cp.trust_score as client_trust_score,
    w.full_name as worker_name,
    w.phone_number as worker_phone,
    wp.verification_status as worker_verification,
    CASE 
        WHEN j.status IN ('posted', 'matched') THEN 
            EXTRACT(EPOCH FROM (NOW() - j.created_at))/3600
        ELSE NULL 
    END as hours_waiting
FROM jobs j
JOIN users c ON j.client_id = c.id
LEFT JOIN client_profiles cp ON j.client_profile_id = cp.id
LEFT JOIN bookings b ON j.id = b.job_id
LEFT JOIN worker_profiles wp ON b.worker_id = wp.id
LEFT JOIN users w ON wp.user_id = w.id
WHERE j.status IN ('posted', 'matched', 'accepted', 'in_progress');

-- SMS delivery analytics
CREATE VIEW sms_delivery_stats AS
SELECT 
    DATE_TRUNC('day', sl.created_at) as day,
    sl.notification_type,
    sl.televeret_status,
    COUNT(*) as count,
    AVG(sl.delivery_time_seconds) as avg_delivery_seconds,
    SUM(sl.cost_etb) as total_cost_etb
FROM sms_logs sl
WHERE sl.created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', sl.created_at), sl.notification_type, sl.televeret_status
ORDER BY day DESC;