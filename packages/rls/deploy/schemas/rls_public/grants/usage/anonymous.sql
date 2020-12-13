-- Deploy: schemas/rls_public/grants/usage/anonymous to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;

GRANT USAGE
ON SCHEMA "rls_public"
TO anonymous;
COMMIT;
