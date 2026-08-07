-- Verify schemas/object_tree_private/schema  on pg

BEGIN;

SELECT assert_schema('object_tree_private'::regnamespace);

ROLLBACK;
