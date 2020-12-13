-- Deploy: schemas/rls_public/tables/user_connections/policies/authenticated_can_delete_on_user_connections to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_connections/table
-- requires: schemas/rls_public/tables/user_connections/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_delete_on_user_connections ON "rls_public".user_connections FOR DELETE TO authenticated USING ( responder_id = "rls_roles_public".get_current_user_id() OR requester_id = "rls_roles_public".get_current_user_id() );
COMMIT;
