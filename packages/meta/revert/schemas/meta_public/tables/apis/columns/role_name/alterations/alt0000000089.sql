-- Revert: schemas/meta_public/tables/apis/columns/role_name/alterations/alt0000000089 from pg

BEGIN;


ALTER TABLE "meta_public".apis 
    ALTER COLUMN role_name DROP NOT NULL;


COMMIT;  

