-- Revert: schemas/meta_public/tables/apis/columns/owner_id/alterations/alt0000000093 from pg

BEGIN;


ALTER TABLE "meta_public".apis 
    ALTER COLUMN owner_id DROP NOT NULL;


COMMIT;  

