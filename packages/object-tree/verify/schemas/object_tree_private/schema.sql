-- Verify schemas/object_tree_private/schema  on pg

BEGIN;

SELECT verify_schema ('object_tree_private');

ROLLBACK;
