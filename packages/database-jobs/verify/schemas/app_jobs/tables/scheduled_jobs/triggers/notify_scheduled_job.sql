-- Verify schemas/app_jobs/tables/scheduled_jobs/triggers/notify_scheduled_job  on pg

BEGIN;


SELECT assert_trigger('app_jobs.scheduled_jobs'::regclass, '_900_notify_scheduled_job', 'app_jobs.do_notify'::regproc, 5);

ROLLBACK;
