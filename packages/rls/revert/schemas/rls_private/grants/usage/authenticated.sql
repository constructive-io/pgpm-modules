-- Revert: schemas/rls_private/grants/usage/authenticated from pg

BEGIN;


REVOKE USAGE
ON SCHEMA "rls_private"
FROM authenticated;

COMMIT;  

