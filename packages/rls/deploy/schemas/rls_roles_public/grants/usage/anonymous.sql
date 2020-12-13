-- Deploy: schemas/rls_roles_public/grants/usage/anonymous to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_public/schema

BEGIN;

GRANT USAGE
ON SCHEMA "rls_roles_public"
TO anonymous;
COMMIT;
