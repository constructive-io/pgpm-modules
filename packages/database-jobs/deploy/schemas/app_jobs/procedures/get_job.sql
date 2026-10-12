-- Deploy schemas/app_jobs/procedures/get_job to pg
-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/job_queues/table
-- requires: schemas/app_jobs/tables/jobs/table
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;
CREATE FUNCTION app_jobs.get_job (
  worker_id text,
  task_identifiers text[] DEFAULT NULL,
  job_expiry interval DEFAULT '4 hours'
)
  RETURNS app_jobs.jobs
  LANGUAGE plpgsql
  AS $$
DECLARE
  claimed app_jobs.jobs;
  claim_at timestamptz = now();
  claim_token text = clock_timestamp()::text || '|';
  claimed_job_id bigint;
  claimed_queue text;
BEGIN
  IF worker_id IS NULL THEN
    PERFORM errors.raise_error('INVALID_WORKER_ID', '{}'::jsonb, 'internal');
  END IF;

  -- One claim, no loop. A named queue runs one job at a time, so the scan may
  -- only pick a named job whose queue row it can lock right now: the row is
  -- taken with SKIP LOCKED before the job, so a row held by another claimer,
  -- or by a producer whose transaction is still open, is skipped and never
  -- waited on. The first queue found in flux is remembered in a
  -- transaction-local setting, tagged with this call's token so an earlier
  -- call in the same transaction cannot leak into it, and the rest of the scan
  -- skips it. The queue is stamped only if the chosen job is still its first
  -- claimable job, and the job is locked last, so a queue never runs out of
  -- (priority, run_at, id) order and a losing claimer holds no job lock. An
  -- expired lock is free. A NULL-queue job never touches job_queues: the
  -- scan, then the job update.
  SELECT c.id, c.queue_name
    INTO claimed_job_id, claimed_queue
  FROM app_jobs.jobs AS c
  WHERE (c.locked_at IS NULL
      OR c.locked_at < (claim_at - job_expiry))
    AND c.run_at <= claim_at
    AND c.attempts < c.max_attempts
    AND (task_identifiers IS NULL
      OR c.task_identifier = ANY (task_identifiers))
    AND CASE
      WHEN c.queue_name IS NULL THEN true
      WHEN c.queue_name IN (
        SELECT jq.queue_name
        FROM app_jobs.job_queues AS jq
        WHERE jq.locked_at IS NOT NULL
          AND jq.locked_at >= (claim_at - job_expiry)
      ) THEN false
      WHEN current_setting('app_jobs.get_job_skip', true) = claim_token || c.queue_name THEN false
      WHEN EXISTS (
        SELECT 1
        FROM app_jobs.job_queues AS q
        WHERE q.queue_name = c.queue_name
        FOR UPDATE SKIP LOCKED
      ) AND EXISTS (
        SELECT 1
        FROM app_jobs.jobs AS x
        WHERE x.id = c.id
        FOR UPDATE SKIP LOCKED
      ) THEN true
      ELSE set_config('app_jobs.get_job_skip', claim_token || c.queue_name, true) IS NULL
    END
  ORDER BY c.priority ASC, c.run_at ASC, c.id ASC
  LIMIT 1
  FOR UPDATE OF c SKIP LOCKED;

  IF claimed_job_id IS NULL THEN
    RETURN NULL;
  END IF;

  IF claimed_queue IS NOT NULL THEN
    -- The scan already holds this queue row, so stamping it cannot block.
    UPDATE app_jobs.job_queues AS jq
    SET locked_by = worker_id, locked_at = claim_at
    WHERE jq.queue_name = claimed_queue
      AND (jq.locked_at IS NULL
        OR jq.locked_at < (claim_at - job_expiry))
      AND (position(claim_token IN coalesce(current_setting('app_jobs.get_job_skip', true), '')) <> 1
        OR (
        SELECT h.id
        FROM app_jobs.jobs AS h
        WHERE h.queue_name = claimed_queue
          AND (h.locked_at IS NULL
            OR h.locked_at < (claim_at - job_expiry))
          AND h.run_at <= claim_at
          AND h.attempts < h.max_attempts
          AND (task_identifiers IS NULL
            OR h.task_identifier = ANY (task_identifiers))
        ORDER BY h.priority ASC, h.run_at ASC, h.id ASC
        LIMIT 1
      ) = claimed_job_id);

    IF NOT FOUND THEN
      RETURN NULL;
    END IF;
  END IF;

  UPDATE app_jobs.jobs AS j
  SET
    attempts = j.attempts + 1,
    locked_by = worker_id,
    locked_at = claim_at
  WHERE j.id = claimed_job_id
  RETURNING j.* INTO claimed;

  RETURN claimed;
END;
$$;
COMMIT;
