-- Verify schemas/metaschema_public/tables/limit_function/table on pg

BEGIN;

SELECT verify_table ('metaschema_public.limit_function');

ROLLBACK;
