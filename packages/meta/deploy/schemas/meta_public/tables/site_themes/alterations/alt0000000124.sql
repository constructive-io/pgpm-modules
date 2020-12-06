-- Deploy: schemas/meta_public/tables/site_themes/alterations/alt0000000124 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/site_themes/table

BEGIN;

ALTER TABLE "meta_public".site_themes
    DISABLE ROW LEVEL SECURITY;
COMMIT;
