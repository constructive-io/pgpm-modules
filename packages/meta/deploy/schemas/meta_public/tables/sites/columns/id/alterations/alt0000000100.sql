-- Deploy: schemas/meta_public/tables/sites/columns/id/alterations/alt0000000100 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/sites/table
-- requires: schemas/meta_public/tables/sites/columns/id/column

BEGIN;

ALTER TABLE "meta_public".sites 
    ALTER COLUMN id SET DEFAULT "meta_private".uuid_generate_v4();
COMMIT;
