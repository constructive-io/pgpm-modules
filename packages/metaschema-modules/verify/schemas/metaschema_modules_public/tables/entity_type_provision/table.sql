-- Verify schemas/metaschema_modules_public/tables/entity_type_provision/table on pg

BEGIN;

SELECT verify_table ('metaschema_modules_public.entity_type_provision');

ROLLBACK;
