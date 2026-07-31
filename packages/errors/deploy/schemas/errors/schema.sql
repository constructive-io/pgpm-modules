-- Deploy schemas/errors/schema to pg

BEGIN;

CREATE SCHEMA errors;

GRANT USAGE ON SCHEMA errors
TO public;

ALTER DEFAULT PRIVILEGES IN SCHEMA errors
GRANT EXECUTE ON FUNCTIONS
TO public;

COMMIT;
