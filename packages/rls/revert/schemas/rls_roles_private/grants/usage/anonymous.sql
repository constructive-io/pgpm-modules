-- Revert: schemas/rls_roles_private/grants/usage/anonymous from pg

BEGIN;


REVOKE USAGE
ON SCHEMA "rls_roles_private"
FROM anonymous;

COMMIT;  

