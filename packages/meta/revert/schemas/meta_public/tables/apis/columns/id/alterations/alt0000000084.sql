-- Revert: schemas/meta_public/tables/apis/columns/id/alterations/alt0000000084 from pg

BEGIN;


ALTER TABLE "meta_public".apis 
    ALTER COLUMN id DROP NOT NULL;


COMMIT;  

