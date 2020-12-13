-- Revert: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/table from pg

BEGIN;
DROP TABLE "rls_encrypted_secrets".user_encrypted_secrets;
COMMIT;  

