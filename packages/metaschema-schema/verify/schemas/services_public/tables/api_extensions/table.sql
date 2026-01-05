-- Verify schemas/services_public/tables/api_extensions/table on pg

BEGIN;

SELECT verify_table ('services_public.api_extensions');

ROLLBACK;
