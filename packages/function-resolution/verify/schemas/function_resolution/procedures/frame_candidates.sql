-- Verify schemas/function_resolution/procedures/frame_candidates  on pg

BEGIN;

SELECT assert_function('function_resolution.frame_candidates(uuid, text, uuid)'::regprocedure);

ROLLBACK;
