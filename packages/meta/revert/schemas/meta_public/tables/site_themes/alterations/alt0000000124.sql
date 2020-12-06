-- Revert: schemas/meta_public/tables/site_themes/alterations/alt0000000124 from pg

BEGIN;


ALTER TABLE "meta_public".site_themes
    ENABLE ROW LEVEL SECURITY;

COMMIT;  

