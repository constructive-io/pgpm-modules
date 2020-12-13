-- Deploy: schemas/rls_roles_private/tables/api_tokens/policies/authenticated_can_delete_on_api_tokens to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_private/schema
-- requires: schemas/rls_roles_private/tables/api_tokens/table
-- requires: schemas/rls_roles_private/tables/api_tokens/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_delete_on_api_tokens ON "rls_roles_private".api_tokens FOR DELETE TO authenticated USING ( user_id = "rls_roles_public".get_current_user_id() );
COMMIT;
