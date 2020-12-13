-- Revert: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE "rls_encrypted_secrets".user_encrypted_secrets FROM authenticated;
COMMIT;  

