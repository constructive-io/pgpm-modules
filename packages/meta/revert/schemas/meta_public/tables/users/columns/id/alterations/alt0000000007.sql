-- Revert: schemas/meta_public/tables/users/columns/id/alterations/alt0000000007 from pg

BEGIN;


ALTER TABLE "meta_public".users 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  

