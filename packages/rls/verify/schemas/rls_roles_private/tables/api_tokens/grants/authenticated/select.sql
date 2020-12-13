-- Verify: schemas/rls_roles_private/tables/api_tokens/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('rls_roles_private.api_tokens', 'select', 'authenticated');
COMMIT;  

