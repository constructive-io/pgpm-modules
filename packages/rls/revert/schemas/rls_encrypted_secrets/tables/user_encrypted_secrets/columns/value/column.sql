-- Revert: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/columns/value/column from pg

BEGIN;


ALTER TABLE "rls_encrypted_secrets".user_encrypted_secrets DROP COLUMN value;
COMMIT;  

