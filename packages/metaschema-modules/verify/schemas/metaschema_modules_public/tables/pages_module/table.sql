-- Verify schemas/metaschema_modules_public/tables/pages_module/table on pg

BEGIN;

SELECT id, database_id, public_schema_id, private_schema_id, merkle_store_module_id,
       site_surface_module_id, sites_table_id, pages_table_id, store_name_prefix, scope, prefix,
       preview_commit_function_name, preview_set_function_name,
       preview_token_mint_function_name, preview_token_verifier_function_name
  FROM metaschema_modules_public.pages_module
 WHERE FALSE;

ROLLBACK;
