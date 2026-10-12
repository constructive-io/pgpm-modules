-- Deploy schemas/app_jobs/procedures/fail_jobs_for_worker to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/jobs/table
-- requires: schemas/app_jobs/tables/job_queues/table
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- fail_job for a batch: error_messages[i] is the error for job_ids[i]. Each
-- job worker_id holds is released with that error and the same back-off as
-- fail_job (exp(min(attempts, 10)) seconds past the later of now and run_at),
-- and its named queue is freed. Ids the worker does not hold are ignored;
-- the rows actually failed are returned. Duplicate ids are rejected
-- (DUPLICATE_JOB_IDS) so each job gets exactly one error.
-- A failure ends any wait for a deployment (deferred_at is cleared), so a
-- later deferral starts a fresh bounded wait.
CREATE FUNCTION app_jobs.fail_jobs_for_worker (
  worker_id text,
  job_ids bigint[],
  error_messages text[]
)
  RETURNS SETOF app_jobs.jobs
  LANGUAGE plpgsql
  AS $$
DECLARE
  queue_names text[];
BEGIN
  IF worker_id IS NULL THEN
    PERFORM errors.raise_error('INVALID_WORKER_ID', '{}'::jsonb, 'internal');
  END IF;

  IF job_ids IS NULL THEN
    RETURN;
  END IF;

  IF cardinality(job_ids) <> (SELECT count(DISTINCT job_id) FROM unnest(job_ids) AS job_id) THEN
    PERFORM errors.raise_error(
      'DUPLICATE_JOB_IDS',
      jsonb_build_object('job_ids', to_jsonb(job_ids)),
      'internal'
    );
  END IF;

  IF error_messages IS NULL
    OR cardinality(error_messages) <> cardinality(job_ids) THEN
    PERFORM errors.raise_error(
      'JOB_FAILURE_ARRAYS_MISMATCH',
      jsonb_build_object(
        'job_ids', cardinality(job_ids),
        'error_messages', cardinality(error_messages)
      ),
      'internal'
    );
  END IF;

  SELECT array_agg(DISTINCT j.queue_name)
    INTO queue_names
  FROM app_jobs.jobs AS j
  WHERE j.id = ANY (job_ids)
    AND j.locked_by = worker_id
    AND j.queue_name IS NOT NULL;

  IF queue_names IS NOT NULL THEN
    UPDATE app_jobs.job_queues AS jq
    SET locked_by = NULL,
        locked_at = NULL
    WHERE jq.queue_name = ANY (queue_names)
      AND jq.locked_by = worker_id;
  END IF;

  RETURN QUERY
    UPDATE app_jobs.jobs AS j
    SET last_error = failure.error_message,
        deferred_at = NULL,
        run_at = greatest(now(), j.run_at)
          + (exp(least(j.attempts, 10))::text || ' seconds')::interval,
        locked_by = NULL,
        locked_at = NULL
    FROM unnest(job_ids, error_messages) AS failure (job_id, error_message)
    WHERE j.id = failure.job_id
      AND j.locked_by = worker_id
    RETURNING j.*;
END;
$$;

COMMIT;
