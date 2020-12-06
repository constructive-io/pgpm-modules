-- Revert: schemas/meta_encrypted_secrets/tables/user_encrypted_secrets/columns/name/alterations/alt0000000029 from pg

BEGIN;


ALTER TABLE "meta_encrypted_secrets".user_encrypted_secrets 
    ALTER COLUMN name DROP NOT NULL;


COMMIT;  

