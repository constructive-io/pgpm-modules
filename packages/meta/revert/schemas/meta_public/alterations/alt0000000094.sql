-- Revert: schemas/meta_public/alterations/alt0000000094 from pg

BEGIN;
COMMENT ON CONSTRAINT apis_owner_id_fkey ON "meta_public".apis IS NULL;
COMMIT;  

