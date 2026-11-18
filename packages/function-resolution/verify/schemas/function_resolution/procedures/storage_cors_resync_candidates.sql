-- Verify schemas/function_resolution/procedures/storage_cors_resync_candidates on pg

BEGIN;

SELECT assert_function('function_resolution.storage_cors_resync_candidates(uuid)'::regprocedure);

ROLLBACK;
