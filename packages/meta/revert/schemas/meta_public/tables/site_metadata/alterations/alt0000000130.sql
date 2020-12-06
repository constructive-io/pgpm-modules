-- Revert: schemas/meta_public/tables/site_metadata/alterations/alt0000000130 from pg

BEGIN;


ALTER TABLE "meta_public".site_metadata
    ENABLE ROW LEVEL SECURITY;

COMMIT;  

