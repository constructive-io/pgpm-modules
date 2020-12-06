-- Deploy: schemas/meta_public/tables/apis/columns/role_name/alterations/alt0000000090 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/apis/table
-- requires: schemas/meta_public/tables/apis/columns/role_name/column

BEGIN;

ALTER TABLE "meta_public".apis 
    ALTER COLUMN role_name SET DEFAULT 'authenticated';
COMMIT;
