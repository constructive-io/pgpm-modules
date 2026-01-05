-- Verify schemas/metaschema_modules_public/tables/tokens_module/table on pg

BEGIN;

SELECT verify_table ('metaschema_modules_public.tokens_module');

ROLLBACK;
