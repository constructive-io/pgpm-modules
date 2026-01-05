-- Revert schemas/services_public/tables/api_schemata/table from pg

BEGIN;

DROP TABLE services_public.api_schemata;

COMMIT;
