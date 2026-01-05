-- Revert schemas/services_public/tables/api_extensions/table from pg

BEGIN;

DROP TABLE services_public.api_extensions;

COMMIT;
