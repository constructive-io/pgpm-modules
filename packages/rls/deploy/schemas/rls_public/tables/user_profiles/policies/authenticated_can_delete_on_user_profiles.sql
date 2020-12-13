-- Deploy: schemas/rls_public/tables/user_profiles/policies/authenticated_can_delete_on_user_profiles to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_profiles/table
-- requires: schemas/rls_public/tables/user_profiles/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_delete_on_user_profiles ON "rls_public".user_profiles FOR DELETE TO authenticated USING ( user_id = "rls_roles_public".get_current_user_id() );
COMMIT;
