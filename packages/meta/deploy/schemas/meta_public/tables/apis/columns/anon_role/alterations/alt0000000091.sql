-- Deploy: schemas/meta_public/tables/apis/columns/anon_role/alterations/alt0000000091 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/apis/table
-- requires: schemas/meta_public/tables/apis/columns/anon_role/column

BEGIN;

ALTER TABLE "meta_public".apis 
    ALTER COLUMN anon_role SET NOT NULL;
COMMIT;
