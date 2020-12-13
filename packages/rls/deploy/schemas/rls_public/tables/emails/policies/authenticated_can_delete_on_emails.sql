-- Deploy: schemas/rls_public/tables/emails/policies/authenticated_can_delete_on_emails to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/emails/table
-- requires: schemas/rls_public/tables/emails/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_delete_on_emails ON "rls_public".emails FOR DELETE TO authenticated USING ( owner_id = "rls_roles_public".get_current_user_id() );
COMMIT;
