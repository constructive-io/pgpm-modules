-- Deploy: schemas/rls_public/tables/user_settings/policies/authenticated_can_select_on_user_settings to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_settings/table
-- requires: schemas/rls_public/tables/user_settings/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_select_on_user_settings ON "rls_public".user_settings FOR SELECT TO authenticated USING ( user_id = "rls_roles_public".get_current_user_id() );
COMMIT;
