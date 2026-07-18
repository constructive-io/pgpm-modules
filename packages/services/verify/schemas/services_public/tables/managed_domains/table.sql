-- Verify schemas/services_public/tables/managed_domains/table

BEGIN;

SELECT
    id,
    database_id,
    domain,
    is_wildcard,
    allow_public_usage,
    verification_status,
    verified_at,
    tls_status,
    tls_ready_at,
    cert_status,
    annotations
FROM services_public.managed_domains
WHERE false;

ROLLBACK;
