-- Deploy: schemas/rls_roles_public/grants/usage/authenticated to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_public/schema

BEGIN;

GRANT USAGE
ON SCHEMA "rls_roles_public"
TO authenticated;
COMMIT;
