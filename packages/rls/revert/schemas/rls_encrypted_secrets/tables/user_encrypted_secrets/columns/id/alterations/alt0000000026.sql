-- Revert: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/columns/id/alterations/alt0000000026 from pg

BEGIN;


ALTER TABLE "rls_encrypted_secrets".user_encrypted_secrets 
    ALTER COLUMN id DROP NOT NULL;


COMMIT;  

