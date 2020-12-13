-- Deploy: schemas/rls_public/tables/user_settings/columns/user_id/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_settings/table

BEGIN;

ALTER TABLE "rls_public".user_settings ADD COLUMN user_id uuid;
COMMIT;
