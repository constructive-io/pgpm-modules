-- Revert: schemas/meta_public/tables/apis/columns/domain_id/alterations/alt0000000095 from pg

BEGIN;


ALTER TABLE "meta_public".apis 
    ALTER COLUMN domain_id DROP NOT NULL;


COMMIT;  

