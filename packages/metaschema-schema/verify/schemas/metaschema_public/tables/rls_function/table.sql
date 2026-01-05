-- Verify schemas/metaschema_public/tables/rls_function/table on pg

BEGIN;

SELECT verify_table ('metaschema_public.rls_function');

ROLLBACK;
