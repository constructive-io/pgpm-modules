-- Verify schemas/partman/procedures/remove_parent_by_id on pg

BEGIN;

SELECT assert_function('partman.remove_parent_by_id(uuid)'::regprocedure);

ROLLBACK;
