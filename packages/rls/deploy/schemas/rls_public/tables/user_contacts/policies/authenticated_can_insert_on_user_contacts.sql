-- Deploy: schemas/rls_public/tables/user_contacts/policies/authenticated_can_insert_on_user_contacts to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_contacts/table
-- requires: schemas/rls_public/tables/user_contacts/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_insert_on_user_contacts ON "rls_public".user_contacts FOR INSERT TO authenticated WITH CHECK ( user_id = "rls_roles_public".get_current_user_id() );
COMMIT;
