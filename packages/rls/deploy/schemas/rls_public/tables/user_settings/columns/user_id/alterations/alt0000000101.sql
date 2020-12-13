-- Deploy: schemas/rls_public/tables/user_settings/columns/user_id/alterations/alt0000000101 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_settings/table
-- requires: schemas/rls_public/tables/user_settings/columns/user_id/column

BEGIN;

ALTER TABLE "rls_public".user_settings 
    ALTER COLUMN user_id SET NOT NULL;
COMMIT;
