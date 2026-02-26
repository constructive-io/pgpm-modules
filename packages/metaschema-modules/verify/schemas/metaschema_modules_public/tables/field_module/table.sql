-- Verify schemas/metaschema_modules_public/tables/field_module/table on pg

BEGIN;

SELECT verify_table ('metaschema_modules_public.field_module');

ROLLBACK;
