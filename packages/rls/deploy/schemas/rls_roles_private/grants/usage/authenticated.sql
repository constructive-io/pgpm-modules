-- Deploy: schemas/rls_roles_private/grants/usage/authenticated to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_private/schema

BEGIN;

GRANT USAGE
ON SCHEMA "rls_roles_private"
TO authenticated;
COMMIT;
