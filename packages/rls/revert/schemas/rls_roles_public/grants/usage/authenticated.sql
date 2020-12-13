-- Revert: schemas/rls_roles_public/grants/usage/authenticated from pg

BEGIN;


REVOKE USAGE
ON SCHEMA "rls_roles_public"
FROM authenticated;

COMMIT;  

