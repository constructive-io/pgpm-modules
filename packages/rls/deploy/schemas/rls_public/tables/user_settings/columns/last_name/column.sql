-- Deploy: schemas/rls_public/tables/user_settings/columns/last_name/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_settings/table

BEGIN;

ALTER TABLE "rls_public".user_settings ADD COLUMN last_name text;
COMMIT;
