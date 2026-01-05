-- Verify schemas/metaschema_public/tables/procedure/table on pg

BEGIN;

SELECT verify_table ('metaschema_public.procedure');

ROLLBACK;
