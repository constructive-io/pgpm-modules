-- Deploy schemas/object_store_private/schema to pg


BEGIN;

CREATE SCHEMA object_store_private;

GRANT USAGE ON SCHEMA object_store_private
TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_private
GRANT EXECUTE ON FUNCTIONS
TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_private
GRANT ALL ON SEQUENCES
TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_private
GRANT ALL ON TABLES
TO authenticated;

COMMIT;
