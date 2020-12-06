-- Revert: schemas/meta_public/tables/apis/columns/schemas/alterations/alt0000000086 from pg

BEGIN;


ALTER TABLE "meta_public".apis 
    ALTER COLUMN schemas DROP NOT NULL;


COMMIT;  

