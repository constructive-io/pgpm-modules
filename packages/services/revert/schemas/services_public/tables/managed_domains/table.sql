-- Revert schemas/services_public/tables/managed_domains/table

BEGIN;

DROP TABLE IF EXISTS services_public.managed_domains;

COMMIT;
