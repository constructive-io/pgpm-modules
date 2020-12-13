-- Deploy: schemas/rls_public/grants/usage/authenticated to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;

GRANT USAGE
ON SCHEMA "rls_public"
TO authenticated;
COMMIT;
