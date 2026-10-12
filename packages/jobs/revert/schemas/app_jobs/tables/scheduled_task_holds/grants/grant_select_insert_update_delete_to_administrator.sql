-- Revert schemas/app_jobs/tables/scheduled_task_holds/grants/grant_select_insert_update_delete_to_administrator from pg

BEGIN;

REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLE app_jobs.scheduled_task_holds FROM administrator;

COMMIT;
