-- Deploy: schemas/meta_public/tables/users/columns/type/alterations/alt0000000008 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/users/table
-- requires: schemas/meta_public/tables/users/columns/type/column

BEGIN;

ALTER TABLE "meta_public".users 
    ALTER COLUMN type SET DEFAULT 0;
COMMIT;
