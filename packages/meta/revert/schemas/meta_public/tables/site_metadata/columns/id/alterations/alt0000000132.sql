-- Revert: schemas/meta_public/tables/site_metadata/columns/id/alterations/alt0000000132 from pg

BEGIN;


ALTER TABLE "meta_public".site_metadata 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  

