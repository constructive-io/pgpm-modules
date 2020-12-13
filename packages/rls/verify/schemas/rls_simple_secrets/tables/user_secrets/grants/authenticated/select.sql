-- Verify: schemas/rls_simple_secrets/tables/user_secrets/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('rls_simple_secrets.user_secrets', 'select', 'authenticated');
COMMIT;  

