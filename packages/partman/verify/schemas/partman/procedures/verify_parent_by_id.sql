-- Verify schemas/partman/procedures/verify_parent_by_id on pg

BEGIN;

SELECT assert_function('partman.verify_parent_by_id(uuid)'::regprocedure);

ROLLBACK;
