-- Revert: schemas/rls_public/grants/usage/anonymous from pg

BEGIN;


REVOKE USAGE
ON SCHEMA "rls_public"
FROM anonymous;

COMMIT;  

