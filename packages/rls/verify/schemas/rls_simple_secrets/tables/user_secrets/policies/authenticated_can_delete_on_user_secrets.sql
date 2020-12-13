-- Verify: schemas/rls_simple_secrets/tables/user_secrets/policies/authenticated_can_delete_on_user_secrets on pg

BEGIN;
SELECT verify_policy('authenticated_can_delete_on_user_secrets', 'rls_simple_secrets.user_secrets');
COMMIT;  

