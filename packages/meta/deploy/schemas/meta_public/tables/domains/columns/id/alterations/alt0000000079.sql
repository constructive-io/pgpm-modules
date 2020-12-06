-- Deploy: schemas/meta_public/tables/domains/columns/id/alterations/alt0000000079 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/domains/table
-- requires: schemas/meta_public/tables/domains/columns/id/column

BEGIN;

ALTER TABLE "meta_public".domains 
    ALTER COLUMN id SET DEFAULT "meta_private".uuid_generate_v4();
COMMIT;
