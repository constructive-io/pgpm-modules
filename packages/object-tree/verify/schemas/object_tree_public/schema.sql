-- Verify schemas/object_tree_public/schema  on pg

BEGIN;

SELECT verify_schema ('object_tree_public');

ROLLBACK;
