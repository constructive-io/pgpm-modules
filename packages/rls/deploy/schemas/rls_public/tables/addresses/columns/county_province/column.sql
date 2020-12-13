-- Deploy: schemas/rls_public/tables/addresses/columns/county_province/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/addresses/table

BEGIN;

ALTER TABLE "rls_public".addresses ADD COLUMN county_province text;
COMMIT;
