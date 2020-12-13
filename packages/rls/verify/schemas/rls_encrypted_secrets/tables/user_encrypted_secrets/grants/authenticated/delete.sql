-- Verify: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('rls_encrypted_secrets.user_encrypted_secrets', 'delete', 'authenticated');
COMMIT;  

