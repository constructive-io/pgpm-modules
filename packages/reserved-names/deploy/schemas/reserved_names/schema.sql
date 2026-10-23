-- Deploy schemas/reserved_names/schema to pg

BEGIN;

CREATE SCHEMA reserved_names;

GRANT USAGE ON SCHEMA reserved_names TO public;

COMMIT;
