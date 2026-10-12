-- Deploy schemas/app_jobs/tables/scheduled_task_holds/grants/grant_select_insert_update_delete_to_administrator to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_task_holds/table

BEGIN;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE app_jobs.scheduled_task_holds TO administrator;

COMMIT;
