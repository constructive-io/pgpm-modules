-- Deploy: schemas/meta_public/tables/apis/columns/schemas/alterations/alt0000000086 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/apis/table
-- requires: schemas/meta_public/tables/apis/columns/schemas/column

BEGIN;

ALTER TABLE "meta_public".apis 
    ALTER COLUMN schemas SET NOT NULL;
COMMIT;
