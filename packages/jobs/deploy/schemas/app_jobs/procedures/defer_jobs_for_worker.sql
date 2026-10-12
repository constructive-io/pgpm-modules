-- Deploy schemas/app_jobs/procedures/defer_jobs_for_worker to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/jobs/table
-- requires: schemas/app_jobs/tables/job_queues/table
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- Hand a worker's claimed jobs back unstarted, without spending the attempt
-- the claim took: the work could not begin yet (its function has no active
-- deployment), which is not a failure of the job. reasons[i] is recorded for
-- job_ids[i] as 'DEFERRED: <reason>'. deferred_at keeps the first deferral so
-- the worker can bound the wait and fail the job loudly once it is spent. The
-- next run waits as long as the job has already been deferred, clamped to
-- 1-30 seconds, so the backoff doubles without a counter. Each job's named
-- queue is freed. Ids the worker does not hold are ignored; the rows actually
-- deferred are returned. Duplicate ids are rejected (DUPLICATE_JOB_IDS).
CREATE FUNCTION app_jobs.defer_jobs_for_worker (
  worker_id text,
  job_ids bigint[],
  reasons text[]
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

  IF reasons IS NULL
    OR cardinality(reasons) <> cardinality(job_ids) THEN
    PERFORM errors.raise_error(
      'JOB_DEFERRAL_ARRAYS_MISMATCH',
      jsonb_build_object(
        'job_ids', cardinality(job_ids),
        'reasons', cardinality(reasons)
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
    SET attempts = greatest(j.attempts - 1, 0),
        last_error = concat('DEFERRED: ', deferral.reason),
        deferred_at = coalesce(j.deferred_at, now()),
        run_at = now() + least(
          greatest(now() - coalesce(j.deferred_at, now()), interval '1 second'),
          interval '30 seconds'
        ),
        locked_by = NULL,
        locked_at = NULL
    FROM unnest(job_ids, reasons) AS deferral (job_id, reason)
    WHERE j.id = deferral.job_id
      AND j.locked_by = worker_id
    RETURNING j.*;
END;
$$;

COMMIT;
