-- Revert: schemas/meta_public/tables/apis/columns/anon_role/alterations/alt0000000092 from pg

BEGIN;


ALTER TABLE "meta_public".apis 
    ALTER COLUMN anon_role DROP DEFAULT;

COMMIT;  

