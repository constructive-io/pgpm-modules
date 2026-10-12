-- Deploy schemas/app_jobs/procedures/complete_jobs_for_worker to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/jobs/table
-- requires: schemas/app_jobs/tables/job_queues/table
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- complete_job for a batch: deletes the jobs in job_ids that worker_id holds
-- and frees their named queues. Ids the worker does not hold (another
-- worker's, already completed, unknown) are ignored; the rows actually
-- completed are returned; duplicate ids are rejected (DUPLICATE_JOB_IDS).
-- Distinct from the administrative complete_jobs(bigint[]), which removes
-- unlocked jobs.
CREATE FUNCTION app_jobs.complete_jobs_for_worker (worker_id text, job_ids bigint[])
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
    DELETE FROM app_jobs.jobs AS j
    WHERE j.id = ANY (job_ids)
      AND j.locked_by = worker_id
    RETURNING j.*;
END;
$$;

COMMIT;
