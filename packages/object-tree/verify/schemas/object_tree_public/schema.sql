-- Verify schemas/object_tree_public/schema  on pg

BEGIN;

SELECT assert_schema('object_tree_public'::regnamespace);

ROLLBACK;
