-- Deploy schemas/object_store_public/schema to pg


BEGIN;

CREATE SCHEMA object_store_public;

GRANT USAGE ON SCHEMA object_store_public
TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_public
GRANT EXECUTE ON FUNCTIONS
TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_public
GRANT ALL ON SEQUENCES
TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_public
GRANT ALL ON TABLES
TO authenticated;

COMMIT;
