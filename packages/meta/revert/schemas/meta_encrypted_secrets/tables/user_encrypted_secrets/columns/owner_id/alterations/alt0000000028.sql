-- Revert: schemas/meta_encrypted_secrets/tables/user_encrypted_secrets/columns/owner_id/alterations/alt0000000028 from pg

BEGIN;


ALTER TABLE "meta_encrypted_secrets".user_encrypted_secrets 
    ALTER COLUMN owner_id DROP NOT NULL;


COMMIT;  

