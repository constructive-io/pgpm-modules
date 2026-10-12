-- Verify schemas/app_jobs/procedures/claim_due_scheduled_jobs  on pg

BEGIN;

SELECT assert_function('app_jobs.claim_due_scheduled_jobs(integer)'::regprocedure);

ROLLBACK;
