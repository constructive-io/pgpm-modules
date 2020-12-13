-- Revert: schemas/rls_roles_public/grants/usage/anonymous from pg

BEGIN;


REVOKE USAGE
ON SCHEMA "rls_roles_public"
FROM anonymous;

COMMIT;  

