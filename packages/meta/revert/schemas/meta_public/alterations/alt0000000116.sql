-- Revert: schemas/meta_public/alterations/alt0000000116 from pg

BEGIN;
COMMENT ON CONSTRAINT api_modules_api_id_fkey ON "meta_public".api_modules IS NULL;
COMMIT;  

