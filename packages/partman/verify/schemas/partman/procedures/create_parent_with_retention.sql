-- Verify schemas/partman/procedures/create_parent_with_retention on pg

BEGIN;

SELECT assert_function('partman.create_parent_with_retention(text, text, text, text, int4, text, bool)'::regprocedure);

ROLLBACK;
