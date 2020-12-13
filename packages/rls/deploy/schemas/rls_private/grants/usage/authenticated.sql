-- Deploy: schemas/rls_private/grants/usage/authenticated to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_private/schema

BEGIN;

GRANT USAGE
ON SCHEMA "rls_private"
TO authenticated;
COMMIT;
