-- Deploy: schemas/meta_public/tables/site_modules/alterations/alt0000000117 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/site_modules/table

BEGIN;

ALTER TABLE "meta_public".site_modules
    DISABLE ROW LEVEL SECURITY;
COMMIT;
