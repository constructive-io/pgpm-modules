-- Revert: schemas/meta_public/tables/apis/columns/role_name/alterations/alt0000000090 from pg

BEGIN;


ALTER TABLE "meta_public".apis 
    ALTER COLUMN role_name DROP DEFAULT;

COMMIT;  

