-- Revert: schemas/meta_public/alterations/alt0000000129 from pg

BEGIN;
COMMENT ON CONSTRAINT site_themes_site_id_fkey ON "meta_public".site_themes IS NULL;
COMMIT;  

