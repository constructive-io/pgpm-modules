-- Deploy: schemas/rls_simple_secrets/tables/user_secrets/policies/authenticated_can_delete_on_user_secrets to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_simple_secrets/schema
-- requires: schemas/rls_simple_secrets/tables/user_secrets/table
-- requires: schemas/rls_simple_secrets/tables/user_secrets/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_delete_on_user_secrets ON "rls_simple_secrets".user_secrets FOR DELETE TO authenticated USING ( owner_id = "rls_roles_public".get_current_user_id() );
COMMIT;
