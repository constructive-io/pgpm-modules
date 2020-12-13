-- Verify: schemas/rls_roles_private/tables/api_tokens/table on pg

BEGIN;
SELECT verify_table('rls_roles_private.api_tokens');
COMMIT;  

