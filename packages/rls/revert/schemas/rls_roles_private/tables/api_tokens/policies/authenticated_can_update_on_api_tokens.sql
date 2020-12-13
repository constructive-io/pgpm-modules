-- Revert: schemas/rls_roles_private/tables/api_tokens/policies/authenticated_can_update_on_api_tokens from pg

BEGIN;
DROP POLICY authenticated_can_update_on_api_tokens ON "rls_roles_private".api_tokens;
COMMIT;  

