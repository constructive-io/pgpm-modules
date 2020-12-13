-- Revert: schemas/rls_roles_private/grants/usage/authenticated from pg

BEGIN;


REVOKE USAGE
ON SCHEMA "rls_roles_private"
FROM authenticated;

COMMIT;  

