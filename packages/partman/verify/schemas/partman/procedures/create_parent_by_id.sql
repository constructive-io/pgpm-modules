-- Verify schemas/partman/procedures/create_parent_by_id on pg

BEGIN;

SELECT assert_function('partman.create_parent_by_id(uuid, text, text, text, int4, text, bool)'::regprocedure);

ROLLBACK;
