-- Deploy schemas/inflection_db/schema to pg


BEGIN;

CREATE SCHEMA inflection_db;

GRANT USAGE ON SCHEMA inflection_db
TO public;

ALTER DEFAULT PRIVILEGES IN SCHEMA inflection_db
GRANT EXECUTE ON FUNCTIONS
TO public;

COMMIT;
