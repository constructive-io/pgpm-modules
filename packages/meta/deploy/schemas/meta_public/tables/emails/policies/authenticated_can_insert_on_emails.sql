-- Deploy: schemas/meta_public/tables/emails/policies/authenticated_can_insert_on_emails to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/emails/table
-- requires: schemas/meta_public/tables/emails/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_insert_on_emails ON "meta_public".emails FOR INSERT TO authenticated WITH CHECK ( owner_id = "meta_public".get_current_user_id() );
COMMIT;
