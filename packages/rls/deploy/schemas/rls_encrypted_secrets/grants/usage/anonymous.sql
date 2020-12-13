-- Deploy: schemas/rls_encrypted_secrets/grants/usage/anonymous to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_encrypted_secrets/schema

BEGIN;

GRANT USAGE
ON SCHEMA "rls_encrypted_secrets"
TO anonymous;
COMMIT;
