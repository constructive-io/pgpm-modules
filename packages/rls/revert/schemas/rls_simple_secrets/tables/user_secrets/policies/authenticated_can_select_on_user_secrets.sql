-- Revert: schemas/rls_simple_secrets/tables/user_secrets/policies/authenticated_can_select_on_user_secrets from pg

BEGIN;
DROP POLICY authenticated_can_select_on_user_secrets ON "rls_simple_secrets".user_secrets;
COMMIT;  

