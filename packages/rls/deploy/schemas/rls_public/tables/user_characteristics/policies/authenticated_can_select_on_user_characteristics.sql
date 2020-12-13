-- Deploy: schemas/rls_public/tables/user_characteristics/policies/authenticated_can_select_on_user_characteristics to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_characteristics/table
-- requires: schemas/rls_public/tables/user_characteristics/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_select_on_user_characteristics ON "rls_public".user_characteristics FOR SELECT TO authenticated USING ( user_id = "rls_roles_public".get_current_user_id() );
COMMIT;
