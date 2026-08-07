-- Verify schemas/partman/procedures/run_maintenance_by_id on pg

BEGIN;

SELECT assert_function('partman.run_maintenance_by_id(uuid, bool)'::regprocedure);

ROLLBACK;
