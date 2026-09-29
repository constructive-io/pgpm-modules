-- Deploy schemas/app_jobs/procedures/run_scheduled_job to pg
-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/jobs/table
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;
CREATE FUNCTION app_jobs.run_scheduled_job (id bigint, job_expiry interval DEFAULT '1 hours')
  RETURNS app_jobs.jobs
  AS $$
DECLARE
  sched app_jobs.scheduled_jobs;
  j app_jobs.jobs;
  prev_scheduled_id bigint;
  lkd_by text;
BEGIN
  -- lock the schedule row so concurrent runners serialize here
  SELECT
    *
  FROM
    app_jobs.scheduled_jobs s
  WHERE
    s.id = run_scheduled_job.id
  FOR UPDATE INTO sched;
  -- schedule deleted: return a null record so the caller unschedules it
  IF NOT FOUND THEN
    RETURN j;
  END IF;
  prev_scheduled_id := sched.last_scheduled_id;
  -- if it's been scheduled check if it's been run
  IF (sched.last_scheduled_id IS NOT NULL) THEN
    SELECT
      locked_by
    FROM
      app_jobs.jobs js
    WHERE
      js.id = sched.last_scheduled_id
      AND (js.locked_at IS NULL -- never been run
        OR js.locked_at >= (NOW() - job_expiry)
        -- still running within a safe interval
) INTO lkd_by;
    IF (FOUND) THEN
      RAISE EXCEPTION 'ALREADY_SCHEDULED';
    END IF;
  END IF;
  -- a job carrying this key that is already in flight covers this tick, and the
  -- keyed upsert below cannot refresh a locked row
  IF (sched.key IS NOT NULL) THEN
    PERFORM
      1
    FROM
      app_jobs.jobs jl
    WHERE
      jl.key = sched.key
      AND jl.locked_at IS NOT NULL;
    IF (FOUND) THEN
      RAISE EXCEPTION 'ALREADY_SCHEDULED';
    END IF;
  END IF;
  -- insert new job; key is the dedupe identity, so a pending job carrying the
  -- same key is refreshed (same semantics as app_jobs.add_job) instead of
  -- violating jobs_key_key
  INSERT INTO app_jobs.jobs (queue_name, task_identifier, payload, priority, max_attempts, key)
    VALUES (sched.queue_name, sched.task_identifier, sched.payload, sched.priority, sched.max_attempts, sched.key)
  ON CONFLICT (KEY)
    DO UPDATE SET
      task_identifier = excluded.task_identifier, payload = excluded.payload, queue_name = excluded.queue_name, max_attempts = excluded.max_attempts, priority = excluded.priority, run_at = excluded.run_at,
      -- always reset error/retry state
      attempts = 0, last_error = NULL
    WHERE
      jobs.locked_at IS NULL
  RETURNING
    * INTO j;
  -- update the scheduled job; j is null when a BEFORE INSERT trigger suppressed
  -- the transport row (the fire trigger enqueues through its own ledger and
  -- records last_scheduled_id itself), so keep the recorded id in that case
  UPDATE
    app_jobs.scheduled_jobs s
  SET
    last_scheduled = NOW(),
    last_scheduled_id = COALESCE(j.id, s.last_scheduled_id)
  WHERE
    s.id = run_scheduled_job.id
  RETURNING s.* INTO sched;
  -- the fire trigger may also have removed the schedule (circuit breaker):
  -- a null record is the caller's signal to unschedule
  IF NOT FOUND THEN
    RETURN j;
  END IF;
  -- a suppressed transport row is not a deleted schedule. A fire trigger that
  -- enqueued through its own ledger recorded the job on the schedule: hand that
  -- job to the caller. One that suppressed the row and recorded nothing declined
  -- this tick (e.g. it suspended the schedule): a null record, as for a deleted
  -- schedule, so the caller unschedules rather than being handed a stale job.
  IF j.id IS NULL THEN
    IF sched.last_scheduled_id IS NOT DISTINCT FROM prev_scheduled_id THEN
      RETURN j;
    END IF;
    SELECT
      *
    FROM
      app_jobs.jobs js
    WHERE
      js.id = sched.last_scheduled_id INTO j;
    IF NOT FOUND THEN
      PERFORM errors.raise_error('SCHEDULED_JOB_NOT_ENQUEUED', jsonb_build_object('scheduled_job_id', run_scheduled_job.id, 'key', sched.key, 'last_scheduled_id', sched.last_scheduled_id), 'internal');
    END IF;
  END IF;
  RETURN j;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;
COMMIT;
