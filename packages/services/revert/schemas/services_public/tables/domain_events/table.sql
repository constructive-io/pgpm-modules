-- Revert schemas/services_public/tables/domain_events/table

BEGIN;

DROP TABLE IF EXISTS services_public.domain_events;

COMMIT;
