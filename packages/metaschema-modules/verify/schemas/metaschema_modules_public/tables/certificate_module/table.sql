-- Verify schemas/metaschema_modules_public/tables/certificate_module/table on pg

BEGIN;

SELECT verify_table ('metaschema_modules_public.certificate_module');

ROLLBACK;
