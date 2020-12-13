-- Revert: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE "rls_encrypted_secrets".user_encrypted_secrets FROM authenticated;
COMMIT;  

