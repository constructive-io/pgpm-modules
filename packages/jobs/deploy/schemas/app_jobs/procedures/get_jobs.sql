-- Deploy schemas/app_jobs/procedures/get_jobs to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/jobs/table
-- requires: schemas/app_jobs/tables/job_queues/table
-- requires: schemas/app_jobs/procedures/get_job
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- Claims up to n jobs for worker_id in one statement. A batch takes only
-- jobs without a named queue: those carry no queue lock, so a single
-- UPDATE ... FROM (... LIMIT n FOR UPDATE SKIP LOCKED) stamps them all.
-- n <= 1 is exactly get_job, named queues included, returned as zero or
-- one row. Rows come back in claim order (priority, run_at, id) with every
-- column of app_jobs.jobs untouched, identity columns included.
CREATE FUNCTION app_jobs.get_jobs (
  worker_id text,
  task_identifiers text[] DEFAULT NULL,
  n integer DEFAULT 1,
  job_expiry interval DEFAULT '4 hours'
)
  RETURNS SETOF app_jobs.jobs
  LANGUAGE plpgsql
  AS $$
DECLARE
  claim_at timestamptz = now();
BEGIN
  IF worker_id IS NULL THEN
    PERFORM errors.raise_error('INVALID_WORKER_ID', '{}'::jsonb, 'internal');
  END IF;

  IF n IS NULL OR n <= 1 THEN
    RETURN QUERY
      SELECT claimed.*
      FROM app_jobs.get_job(worker_id, task_identifiers, job_expiry) AS claimed
      WHERE claimed.id IS NOT NULL;
    RETURN;
  END IF;

  RETURN QUERY
    WITH picked AS (
      SELECT j.id
      FROM app_jobs.jobs AS j
      WHERE j.queue_name IS NULL
        AND (j.locked_at IS NULL
          OR j.locked_at < (claim_at - job_expiry))
        AND j.run_at <= claim_at
        AND j.attempts < j.max_attempts
        AND (task_identifiers IS NULL
          OR j.task_identifier = ANY (task_identifiers))
      ORDER BY j.priority ASC, j.run_at ASC, j.id ASC
      LIMIT n
      FOR UPDATE SKIP LOCKED
    ),
    stamped AS (
      UPDATE app_jobs.jobs AS j
      SET attempts = j.attempts + 1,
          locked_by = worker_id,
          locked_at = claim_at
      FROM picked
      WHERE j.id = picked.id
      RETURNING j.*
    )
    SELECT *
    FROM stamped
    ORDER BY stamped.priority ASC, stamped.run_at ASC, stamped.id ASC;
END;
$$;

COMMIT;
