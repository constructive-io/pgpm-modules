-- Revert: schemas/rls_simple_secrets/grants/usage/authenticated from pg

BEGIN;


REVOKE USAGE
ON SCHEMA "rls_simple_secrets"
FROM authenticated;

COMMIT;  

