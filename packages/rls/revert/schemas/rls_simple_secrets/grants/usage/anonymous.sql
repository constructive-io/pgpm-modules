-- Revert: schemas/rls_simple_secrets/grants/usage/anonymous from pg

BEGIN;


REVOKE USAGE
ON SCHEMA "rls_simple_secrets"
FROM anonymous;

COMMIT;  

