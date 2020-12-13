-- Deploy: schemas/rls_public/tables/user_settings/columns/id/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_settings/table

BEGIN;

ALTER TABLE "rls_public".user_settings ADD COLUMN id uuid;
COMMIT;
