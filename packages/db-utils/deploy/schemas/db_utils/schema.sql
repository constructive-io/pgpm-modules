-- Deploy schemas/db_utils/schema to pg


BEGIN;

CREATE SCHEMA db_utils;

-- TODO maybe this one should not be public

GRANT USAGE ON SCHEMA db_utils
TO public;

ALTER DEFAULT PRIVILEGES IN SCHEMA db_utils
GRANT EXECUTE ON FUNCTIONS
TO public;

COMMIT;
