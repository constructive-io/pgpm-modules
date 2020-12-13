-- Deploy: schemas/rls_public/tables/addresses/columns/state/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/addresses/table

BEGIN;

ALTER TABLE "rls_public".addresses ADD COLUMN state text;
COMMIT;
