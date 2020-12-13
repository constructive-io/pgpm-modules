-- Revert: schemas/rls_encrypted_secrets/grants/usage/authenticated from pg

BEGIN;


REVOKE USAGE
ON SCHEMA "rls_encrypted_secrets"
FROM authenticated;

COMMIT;  

