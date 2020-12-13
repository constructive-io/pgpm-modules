-- Revert: schemas/rls_public/grants/usage/authenticated from pg

BEGIN;


REVOKE USAGE
ON SCHEMA "rls_public"
FROM authenticated;

COMMIT;  

