-- Deploy: schemas/rls_public/tables/users/columns/id/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table

BEGIN;

ALTER TABLE "rls_public".users ADD COLUMN id uuid;
COMMIT;
