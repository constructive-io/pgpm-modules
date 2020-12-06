-- Revert: schemas/meta_public/tables/domains/columns/owner_id/alterations/alt0000000080 from pg

BEGIN;


ALTER TABLE "meta_public".domains 
    ALTER COLUMN owner_id DROP NOT NULL;


COMMIT;  

