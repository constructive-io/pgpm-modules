-- Revert: schemas/rls_private/grants/usage/anonymous from pg

BEGIN;


REVOKE USAGE
ON SCHEMA "rls_private"
FROM anonymous;

COMMIT;  

