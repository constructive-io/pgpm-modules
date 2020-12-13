-- Verify: schemas/rls_roles_private/tables/api_tokens/policies/authenticated_can_insert_on_api_tokens on pg

BEGIN;
SELECT verify_policy('authenticated_can_insert_on_api_tokens', 'rls_roles_private.api_tokens');
COMMIT;  

