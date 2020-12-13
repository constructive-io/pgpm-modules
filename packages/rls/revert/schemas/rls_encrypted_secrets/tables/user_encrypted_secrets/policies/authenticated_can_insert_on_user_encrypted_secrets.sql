-- Revert: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/policies/authenticated_can_insert_on_user_encrypted_secrets from pg

BEGIN;
DROP POLICY authenticated_can_insert_on_user_encrypted_secrets ON "rls_encrypted_secrets".user_encrypted_secrets;
COMMIT;  

