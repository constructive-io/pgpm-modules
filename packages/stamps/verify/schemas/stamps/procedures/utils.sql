-- Verify schemas/stamps/procedures/utils  on pg

BEGIN;

SELECT assert_function('stamps.peoplestamps()'::regprocedure);
SELECT assert_function('stamps.timestamps()'::regprocedure);

ROLLBACK;
