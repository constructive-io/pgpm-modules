-- Revert: schemas/meta_public/tables/users/columns/type/alterations/alt0000000008 from pg

BEGIN;


ALTER TABLE "meta_public".users 
    ALTER COLUMN type DROP DEFAULT;

COMMIT;  

