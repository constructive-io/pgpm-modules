-- Deploy: schemas/meta_public/tables/apps/columns/id/alterations/alt0000000138 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/apps/table
-- requires: schemas/meta_public/tables/apps/columns/id/column

BEGIN;

ALTER TABLE "meta_public".apps 
    ALTER COLUMN id SET NOT NULL;
COMMIT;
