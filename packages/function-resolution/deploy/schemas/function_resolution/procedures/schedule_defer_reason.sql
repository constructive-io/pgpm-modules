-- Deploy schemas/function_resolution/procedures/schedule_defer_reason to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/resolve
-- requires: pgpm-database-jobs:schemas/app_jobs/tables/scheduled_jobs/table

BEGIN;

-- schedule_defer_reason: the registration check
-- function_resolution.fire_due_scheduled_jobs asks before firing a schedule.
-- NULL when the job the schedule would spawn has a function definition to
-- dispatch to; otherwise the reason it has none yet, so the schedule is
-- deferred instead of spawning a job the worker can only fail ("not
-- registered in function_definitions").
--
-- The lookup is the worker's own for a job spawned from a schedule: the
-- job's database_id and entity_id, the payload's scope (default 'database'),
-- and the payload's node_type for a graph-node payload, else the schedule's
-- task_identifier.
--
-- Function schedules (key 'function_schedule:<id>') are never deferred: their
-- sync trigger refuses to register one without its definition, and their
-- fire trigger resolves that definition itself.
CREATE FUNCTION function_resolution.schedule_defer_reason(
    sched app_jobs.scheduled_jobs
) RETURNS text AS $$
DECLARE
    scope text := 'database';
    task_identifier text := sched.task_identifier;
BEGIN
    IF sched.key LIKE 'function_schedule:%' THEN
        RETURN NULL;
    END IF;

    IF json_typeof(sched.payload -> 'scope') = 'string' THEN
        scope := sched.payload ->> 'scope';
    END IF;

    IF json_typeof(sched.payload -> 'execution_id') = 'string'
       AND json_typeof(sched.payload -> 'node_name') = 'string'
       AND json_typeof(sched.payload -> 'node_type') = 'string'
       AND sched.payload -> 'inputs' IS NOT NULL THEN
        task_identifier := sched.payload ->> 'node_type';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM function_resolution.resolve(
            sched.database_id,
            scope,
            sched.entity_id,
            task_identifier,
            false
        )
    ) THEN
        RETURN NULL;
    END IF;

    RETURN format(
        'FUNCTION_NOT_REGISTERED: no function definition for task_identifier "%s" in the scope chain starting at scope "%s" (database_id=%s)',
        task_identifier, scope, sched.database_id
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION function_resolution.schedule_defer_reason(app_jobs.scheduled_jobs) IS
'Registration check for function_resolution.fire_due_scheduled_jobs: NULL when the job a schedule spawns resolves to a function definition, else the reason it does not yet.';

COMMIT;
