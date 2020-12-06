-- Deploy: schemas/meta_encrypted_secrets/tables/user_encrypted_secrets/policies/authenticated_can_insert_on_user_encrypted_secrets to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_encrypted_secrets/schema
-- requires: schemas/meta_encrypted_secrets/tables/user_encrypted_secrets/table
-- requires: schemas/meta_encrypted_secrets/tables/user_encrypted_secrets/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_insert_on_user_encrypted_secrets ON "meta_encrypted_secrets".user_encrypted_secrets FOR INSERT TO authenticated WITH CHECK ( owner_id = "meta_public".get_current_user_id() );
COMMIT;
