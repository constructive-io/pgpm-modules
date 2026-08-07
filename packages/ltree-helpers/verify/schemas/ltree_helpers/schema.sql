-- Verify schemas/ltree_helpers/schema on pg

BEGIN;

SELECT assert_schema('ltree_helpers'::regnamespace);

ROLLBACK;
