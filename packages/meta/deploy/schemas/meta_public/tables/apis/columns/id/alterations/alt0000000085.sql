-- Deploy: schemas/meta_public/tables/apis/columns/id/alterations/alt0000000085 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/apis/table
-- requires: schemas/meta_public/tables/apis/columns/id/column

BEGIN;

ALTER TABLE "meta_public".apis 
    ALTER COLUMN id SET DEFAULT "meta_private".uuid_generate_v4();
COMMIT;
