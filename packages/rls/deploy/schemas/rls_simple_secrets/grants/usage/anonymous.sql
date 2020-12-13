-- Deploy: schemas/rls_simple_secrets/grants/usage/anonymous to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_simple_secrets/schema

BEGIN;

GRANT USAGE
ON SCHEMA "rls_simple_secrets"
TO anonymous;
COMMIT;
