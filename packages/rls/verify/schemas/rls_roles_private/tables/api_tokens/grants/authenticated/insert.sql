-- Verify: schemas/rls_roles_private/tables/api_tokens/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('rls_roles_private.api_tokens', 'insert', 'authenticated');
COMMIT;  

