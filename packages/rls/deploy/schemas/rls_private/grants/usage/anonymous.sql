-- Deploy: schemas/rls_private/grants/usage/anonymous to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_private/schema

BEGIN;

GRANT USAGE
ON SCHEMA "rls_private"
TO anonymous;
COMMIT;
