-- Deploy schemas/ltree_helpers/schema to pg


BEGIN;

CREATE SCHEMA ltree_helpers;

GRANT USAGE ON SCHEMA ltree_helpers TO public;

ALTER DEFAULT PRIVILEGES IN SCHEMA ltree_helpers
GRANT EXECUTE ON FUNCTIONS
TO public;

COMMIT;
