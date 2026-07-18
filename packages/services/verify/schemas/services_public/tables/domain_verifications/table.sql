-- Verify schemas/services_public/tables/domain_verifications/table

BEGIN;

SELECT
    id,
    owner_id,
    managed_domain_id,
    method,
    record_name,
    record_type,
    record_value,
    status,
    attempts,
    last_checked_at,
    verified_at,
    expires_at,
    error,
    created_at,
    updated_at
FROM services_public.domain_verifications
WHERE false;

ROLLBACK;
