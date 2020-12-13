-- Deploy: schemas/rls_public/tables/user_connections/columns/accepted/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_connections/table

BEGIN;

ALTER TABLE "rls_public".user_connections ADD COLUMN accepted bool;
COMMIT;
