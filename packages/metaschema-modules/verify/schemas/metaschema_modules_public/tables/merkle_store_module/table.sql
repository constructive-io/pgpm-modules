-- Verify schemas/metaschema_modules_public/tables/merkle_store_module/table on pg

BEGIN;

SELECT verify_table ('metaschema_modules_public.merkle_store_module');

ROLLBACK;
