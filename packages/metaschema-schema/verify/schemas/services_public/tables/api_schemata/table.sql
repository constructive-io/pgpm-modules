-- Verify schemas/services_public/tables/api_schemata/table on pg

BEGIN;

SELECT verify_table ('services_public.api_schemata');

ROLLBACK;
