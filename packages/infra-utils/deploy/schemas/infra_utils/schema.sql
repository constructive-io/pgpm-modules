-- Deploy schemas/infra_utils/schema to pg

BEGIN;

CREATE SCHEMA infra_utils;

GRANT USAGE ON SCHEMA infra_utils
TO public;

ALTER DEFAULT PRIVILEGES IN SCHEMA infra_utils
GRANT EXECUTE ON FUNCTIONS
TO public;

COMMIT;
