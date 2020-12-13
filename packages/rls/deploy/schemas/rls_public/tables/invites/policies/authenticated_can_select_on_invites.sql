-- Deploy: schemas/rls_public/tables/invites/policies/authenticated_can_select_on_invites to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table
-- requires: schemas/rls_public/tables/invites/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_select_on_invites ON "rls_public".invites FOR SELECT TO authenticated USING ( sender_id = "rls_roles_public".get_current_user_id() );
COMMIT;
