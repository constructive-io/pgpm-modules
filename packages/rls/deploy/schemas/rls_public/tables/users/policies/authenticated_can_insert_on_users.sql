-- Deploy: schemas/rls_public/tables/users/policies/authenticated_can_insert_on_users to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table
-- requires: schemas/rls_public/tables/users/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_insert_on_users ON "rls_public".users FOR INSERT TO authenticated WITH CHECK ( id = "rls_roles_public".get_current_user_id() );
COMMIT;
