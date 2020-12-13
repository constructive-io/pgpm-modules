-- Deploy: schemas/rls_public/tables/user_settings/policies/enable_row_level_security to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_settings/table

BEGIN;

ALTER TABLE "rls_public".user_settings
    ENABLE ROW LEVEL SECURITY;
COMMIT;
