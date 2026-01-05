-- Verify schemas/metaschema_public/tables/database_extension/table on pg

BEGIN;

SELECT verify_table ('metaschema_public.database_extension');

ROLLBACK;
