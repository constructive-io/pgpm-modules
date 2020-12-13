-- Verify: schemas/rls_simple_secrets/tables/user_secrets/table on pg

BEGIN;
SELECT verify_table('rls_simple_secrets.user_secrets');
COMMIT;  

