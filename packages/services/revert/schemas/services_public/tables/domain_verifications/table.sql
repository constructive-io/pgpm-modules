-- Revert schemas/services_public/tables/domain_verifications/table

BEGIN;

DROP TABLE IF EXISTS services_public.domain_verifications;

COMMIT;
