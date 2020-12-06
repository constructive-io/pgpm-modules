-- Deploy: schemas/meta_simple_secrets/tables/user_secrets/policies/authenticated_can_update_on_user_secrets to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_simple_secrets/schema
-- requires: schemas/meta_simple_secrets/tables/user_secrets/table
-- requires: schemas/meta_simple_secrets/tables/user_secrets/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_update_on_user_secrets ON "meta_simple_secrets".user_secrets FOR UPDATE TO authenticated USING ( owner_id = "meta_public".get_current_user_id() );
COMMIT;
