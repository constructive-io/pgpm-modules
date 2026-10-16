-- Deploy schemas/app_jobs/procedures/scheduled_task_identifiers to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: pgpm-jwt-claims:schemas/jwt_public/procedures/current_role_type
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

/*
 * The task identifiers scheduled for one database, for system handlers that
 * check maintenance registration (billing:doctor). It returns the database's
 * own rows, plus the task of every schedules:fanout lane whose slice
 * (mod(abs(hashtext(database_id)), shard_count) = shard) holds the database,
 * rather than exposing the shared schedule table.
 *
 * It lives beside scheduled_jobs, in a schema the function lane's SQL filter
 * admits (lane handlers already call app_jobs.add_job), because a system
 * handler's statements reach Postgres through that filter. The caller must
 * run with role_type 'system', which the worker stamps only for a
 * platform-tier system definition.
 *
 * A lane row counts only when its payload is one the worker runs: shard_count
 * a positive integer, shard an integer in 0..shard_count-1 (the worker's
 * parseFanoutLanePayload). Nothing checks the payload when the row is written,
 * so a malformed lane is skipped here rather than failing the call for every
 * database. CASE orders the checks, so no cast runs on an unchecked value.
 */
CREATE FUNCTION app_jobs.scheduled_task_identifiers(
  database_id uuid
) RETURNS SETOF text AS $$
BEGIN
  IF jwt_public.current_role_type() IS DISTINCT FROM 'system' THEN
    PERFORM errors.raise_error('FORBIDDEN', '{}'::jsonb, 'internal');
  END IF;

  RETURN QUERY
  SELECT DISTINCT scheduled_jobs.task_identifier
    FROM app_jobs.scheduled_jobs
   WHERE scheduled_jobs.database_id = scheduled_task_identifiers.database_id
  UNION
  SELECT DISTINCT scheduled_jobs.payload ->> 'task'
    FROM app_jobs.scheduled_jobs
   WHERE scheduled_jobs.task_identifier = 'schedules:fanout'
     AND CASE
           WHEN json_typeof(scheduled_jobs.payload -> 'shard_count') IS DISTINCT FROM 'number'
             OR json_typeof(scheduled_jobs.payload -> 'shard') IS DISTINCT FROM 'number' THEN false
           WHEN (scheduled_jobs.payload ->> 'shard_count')::numeric < 1
             OR (scheduled_jobs.payload ->> 'shard_count')::numeric <> trunc((scheduled_jobs.payload ->> 'shard_count')::numeric)
             OR (scheduled_jobs.payload ->> 'shard')::numeric < 0
             OR (scheduled_jobs.payload ->> 'shard')::numeric >= (scheduled_jobs.payload ->> 'shard_count')::numeric
             OR (scheduled_jobs.payload ->> 'shard')::numeric <> trunc((scheduled_jobs.payload ->> 'shard')::numeric) THEN false
           ELSE mod(abs(hashtext(scheduled_task_identifiers.database_id::text)::bigint),
                    (scheduled_jobs.payload ->> 'shard_count')::numeric)
                = (scheduled_jobs.payload ->> 'shard')::numeric
         END;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE EXECUTE ON FUNCTION app_jobs.scheduled_task_identifiers(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app_jobs.scheduled_task_identifiers(uuid) TO authenticated;

COMMIT;
