-- Verify schemas/services_public/tables/domain_events/table

BEGIN;

SELECT
    id,
    owner_id,
    managed_domain_id,
    domain_verification_id,
    event_type,
    actor_id,
    message,
    metadata,
    created_at
FROM services_public.domain_events
WHERE false;

ROLLBACK;
