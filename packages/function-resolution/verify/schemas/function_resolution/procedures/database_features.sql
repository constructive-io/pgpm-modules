-- Verify schemas/function_resolution/procedures/database_features  on pg

BEGIN;

SELECT assert_function('function_resolution.database_features(uuid, uuid)'::regprocedure);

ROLLBACK;
