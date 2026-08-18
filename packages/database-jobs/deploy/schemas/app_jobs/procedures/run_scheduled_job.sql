-- Deploy schemas/app_jobs/procedures/run_scheduled_job to pg
-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/jobs/table
-- requires: schemas/app_jobs/tables/scheduled_jobs/table

BEGIN;
CREATE FUNCTION app_jobs.run_scheduled_job (id bigint, job_expiry interval DEFAULT '1 hours')
  RETURNS app_jobs.jobs
  AS $$
DECLARE
  sched app_jobs.scheduled_jobs;
  j app_jobs.jobs;
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
  INSERT INTO app_jobs.jobs (
    database_id,
    actor_id,
    entity_id,
    queue_name,
    task_identifier,
    payload,
    priority,
    max_attempts,
    key
  ) VALUES (
    sched.database_id,
    sched.actor_id,
    sched.entity_id,
    sched.queue_name,
    sched.task_identifier,
    sched.payload,
    sched.priority,
    sched.max_attempts,
    sched.key
  )
  ON CONFLICT (KEY)
    DO UPDATE SET
      database_id = excluded.database_id, actor_id = excluded.actor_id, entity_id = excluded.entity_id,
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
    s.id = run_scheduled_job.id;
  RETURN j;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;
COMMIT;
