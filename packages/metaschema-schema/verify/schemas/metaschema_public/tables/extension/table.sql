-- Verify schemas/metaschema_public/tables/extension/table on pg

BEGIN;

SELECT verify_table ('metaschema_public.extension');

ROLLBACK;
