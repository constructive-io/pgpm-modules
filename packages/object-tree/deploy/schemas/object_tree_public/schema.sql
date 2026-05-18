-- Deploy schemas/object_tree_public/schema to pg


BEGIN;

CREATE SCHEMA object_tree_public;

GRANT USAGE ON SCHEMA object_tree_public
TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_tree_public
GRANT EXECUTE ON FUNCTIONS
TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_tree_public
GRANT ALL ON SEQUENCES
TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_tree_public
GRANT ALL ON TABLES
TO authenticated;

COMMIT;
