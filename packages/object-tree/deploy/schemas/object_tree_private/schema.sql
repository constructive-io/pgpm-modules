-- Deploy schemas/object_tree_private/schema to pg


BEGIN;

CREATE SCHEMA object_tree_private;

GRANT USAGE ON SCHEMA object_tree_private
TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_tree_private
GRANT EXECUTE ON FUNCTIONS
TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_tree_private
GRANT ALL ON SEQUENCES
TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_tree_private
GRANT ALL ON TABLES
TO authenticated;

COMMIT;
