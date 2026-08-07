-- Verify schemas/status_public/procedures/steps_required  on pg

BEGIN;

SELECT assert_function('status_public.steps_required(text, uuid)'::regprocedure);

ROLLBACK;
