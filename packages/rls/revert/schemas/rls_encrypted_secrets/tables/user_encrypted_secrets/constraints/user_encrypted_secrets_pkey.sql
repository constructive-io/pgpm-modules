-- Revert: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/constraints/user_encrypted_secrets_pkey from pg

BEGIN;


ALTER TABLE "rls_encrypted_secrets".user_encrypted_secrets 
    DROP CONSTRAINT user_encrypted_secrets_pkey;

COMMIT;  

