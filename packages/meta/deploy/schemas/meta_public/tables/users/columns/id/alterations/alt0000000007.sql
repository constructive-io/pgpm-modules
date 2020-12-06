-- Deploy: schemas/meta_public/tables/users/columns/id/alterations/alt0000000007 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/users/table
-- requires: schemas/meta_public/tables/users/columns/id/column

BEGIN;

ALTER TABLE "meta_public".users 
    ALTER COLUMN id SET DEFAULT "meta_private".uuid_generate_v4();
COMMIT;
