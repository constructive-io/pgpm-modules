-- Deploy: schemas/meta_public/tables/apps/alterations/alt0000000137 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/apps/table

BEGIN;

ALTER TABLE "meta_public".apps
    DISABLE ROW LEVEL SECURITY;
COMMIT;
