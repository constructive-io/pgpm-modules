-- Revert: schemas/meta_public/tables/sites/columns/domain_id/alterations/alt0000000105 from pg

BEGIN;


ALTER TABLE "meta_public".sites 
    ALTER COLUMN domain_id DROP NOT NULL;


COMMIT;  

