-- Revert: schemas/rls_encrypted_secrets/grants/usage/anonymous from pg

BEGIN;


REVOKE USAGE
ON SCHEMA "rls_encrypted_secrets"
FROM anonymous;

COMMIT;  

