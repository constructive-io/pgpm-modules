\echo Use "CREATE EXTENSION pgpm-jobs" to load this file. \quit
CREATE SCHEMA IF NOT EXISTS app_jobs;

GRANT USAGE ON SCHEMA app_jobs TO administrator;

GRANT USAGE ON SCHEMA app_jobs TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA app_jobs
  GRANT EXECUTE ON FUNCTIONS TO administrator;

CREATE FUNCTION app_jobs.tg_update_timestamps() RETURNS trigger AS $EOFCODE$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.created_at = NOW();
    NEW.updated_at = NOW();
  ELSIF TG_OP = 'UPDATE' THEN
    NEW.created_at = OLD.created_at;
    NEW.updated_at = greatest (now(), OLD.updated_at + interval '1 millisecond');
  END IF;
  RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql;

CREATE FUNCTION app_jobs.tg_add_job_with_row_id() RETURNS trigger AS $EOFCODE$
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    PERFORM
      app_jobs.add_job (tg_argv[0], json_build_object('id', NEW.id));
    RETURN NEW;
  END IF;
  IF (TG_OP = 'DELETE') THEN
    PERFORM
      app_jobs.add_job (tg_argv[0], json_build_object('id', OLD.id));
    RETURN OLD;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION app_jobs.tg_add_job_with_row_id IS 'Useful shortcut to create a job on insert or update. Pass the task name as the trigger argument, and the record id will automatically be available on the JSON payload.';

CREATE FUNCTION app_jobs.tg_add_job_with_row() RETURNS trigger AS $EOFCODE$
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    PERFORM
      app_jobs.add_job (TG_ARGV[0], to_json(NEW));
    RETURN NEW;
  END IF;
  IF (TG_OP = 'DELETE') THEN
    PERFORM
      app_jobs.add_job (TG_ARGV[0], to_json(OLD));
    RETURN OLD;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION app_jobs.tg_add_job_with_row IS 'Useful shortcut to create a job on insert or update. Pass the task name as the trigger argument, and the record data will automatically be available on the JSON payload.';

CREATE FUNCTION app_jobs.json_build_object_apply(
  arguments text[]
) RETURNS pg_catalog.json AS $EOFCODE$
DECLARE
  arg text;
  _sql text;
  _res json;
  args text[];
BEGIN
  _sql = 'SELECT json_build_object(';
  FOR arg IN
  SELECT
    unnest(arguments)
    LOOP
      args = array_append(args, format('''%s''', arg));
    END LOOP;
  _sql = _sql || format('%s);', array_to_string(args, ','));
  EXECUTE _sql INTO _res;
  RETURN _res;
END;
$EOFCODE$ LANGUAGE plpgsql;

CREATE FUNCTION app_jobs.trigger_job_with_fields() RETURNS trigger AS $EOFCODE$
DECLARE
  arg text;
  fn text;
  i int;
  args text[];
BEGIN
  FOR i IN
  SELECT
    *
  FROM
    generate_series(1, TG_NARGS) g (i)
    LOOP
      IF (i = 1) THEN
        fn = TG_ARGV[i - 1];
      ELSE
        args = array_append(args, TG_ARGV[i - 1]);
        IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
          EXECUTE format('SELECT ($1).%s::text', TG_ARGV[i - 1])
          USING NEW INTO arg;
        END IF;
        IF (TG_OP = 'DELETE') THEN
          EXECUTE format('SELECT ($1).%s::text', TG_ARGV[i - 1])
          USING OLD INTO arg;
        END IF;
        args = array_append(args, arg);
      END IF;
    END LOOP;
  PERFORM
    app_jobs.add_job (fn, app_jobs.json_build_object_apply (args));
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    RETURN NEW;
  END IF;
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE TABLE app_jobs.scheduled_jobs (
  id bigserial PRIMARY KEY,
  queue_name text DEFAULT (public.gen_random_uuid())::text,
  task_identifier text NOT NULL,
  payload pg_catalog.json DEFAULT '{}'::json NOT NULL,
  priority int DEFAULT 0 NOT NULL,
  max_attempts int DEFAULT 25 NOT NULL,
  key text,
  schedule_info pg_catalog.json NOT NULL,
  next_run_at timestamptz,
  last_error text,
  last_error_at timestamptz,
  last_scheduled timestamptz,
  last_scheduled_id bigint,
  CHECK (length(key) < 513),
  CHECK (length(task_identifier) < 127),
  CHECK (max_attempts > 0),
  CHECK (length(queue_name) < 127),
  UNIQUE (key)
);

COMMENT ON TABLE app_jobs.scheduled_jobs IS 'Recurring/cron-style job definitions: each row spawns jobs on a schedule defined by schedule_info';

COMMENT ON COLUMN app_jobs.scheduled_jobs.id IS 'Auto-incrementing scheduled job identifier';

COMMENT ON COLUMN app_jobs.scheduled_jobs.queue_name IS 'Name of the queue spawned jobs are placed into';

COMMENT ON COLUMN app_jobs.scheduled_jobs.task_identifier IS 'Task type identifier for spawned jobs';

COMMENT ON COLUMN app_jobs.scheduled_jobs.payload IS 'JSON payload passed to each spawned job';

COMMENT ON COLUMN app_jobs.scheduled_jobs.priority IS 'Priority assigned to spawned jobs (lower = higher priority)';

COMMENT ON COLUMN app_jobs.scheduled_jobs.max_attempts IS 'Max retry attempts for spawned jobs';

COMMENT ON COLUMN app_jobs.scheduled_jobs.key IS 'Optional unique deduplication key';

COMMENT ON COLUMN app_jobs.scheduled_jobs.schedule_info IS 'JSON schedule configuration (e.g. cron expression, interval)';

COMMENT ON COLUMN app_jobs.scheduled_jobs.last_scheduled IS 'Timestamp when a job was last spawned from this schedule';

COMMENT ON COLUMN app_jobs.scheduled_jobs.last_scheduled_id IS 'ID of the last job spawned from this schedule';

COMMENT ON COLUMN app_jobs.scheduled_jobs.next_run_at IS 'Next instant this schedule fires, computed from schedule_info by app_jobs.schedule_next_run; app_jobs.fire_due_scheduled_jobs, called on a fixed interval by the schedule clock, fires every row whose next_run_at has passed';

COMMENT ON COLUMN app_jobs.scheduled_jobs.last_error IS 'Error raised the last time fire_due_scheduled_jobs tried to spawn this schedule; cleared when a spawn succeeds';

COMMENT ON COLUMN app_jobs.scheduled_jobs.last_error_at IS 'When last_error was recorded';

CREATE FUNCTION app_jobs.do_notify() RETURNS trigger AS $EOFCODE$
BEGIN
  PERFORM
    pg_notify(TG_ARGV[0], '');
  RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql;

CREATE INDEX scheduled_jobs_priority_id_idx ON app_jobs.scheduled_jobs (priority, id);

GRANT SELECT, INSERT, UPDATE, DELETE ON app_jobs.scheduled_jobs TO administrator;

CREATE TABLE app_jobs.jobs (
  id bigserial PRIMARY KEY,
  queue_name text DEFAULT (public.gen_random_uuid())::text,
  task_identifier text NOT NULL,
  payload pg_catalog.json DEFAULT '{}'::json NOT NULL,
  priority int DEFAULT 0 NOT NULL,
  run_at timestamptz DEFAULT now() NOT NULL,
  attempts int DEFAULT 0 NOT NULL,
  max_attempts int DEFAULT 25 NOT NULL,
  key text,
  last_error text,
  locked_at timestamptz,
  locked_by text,
  deferred_at timestamptz,
  CHECK (length(key) < 513),
  CHECK (length(task_identifier) < 127),
  CHECK (max_attempts > 0),
  CHECK (length(queue_name) < 127),
  CHECK (length(locked_by) > 3),
  UNIQUE (key)
);

COMMENT ON TABLE app_jobs.jobs IS 'Background job queue: each row is a pending or in-progress task to be executed by a worker';

COMMENT ON COLUMN app_jobs.jobs.id IS 'Auto-incrementing job identifier';

COMMENT ON COLUMN app_jobs.jobs.queue_name IS 'Name of the queue this job belongs to; used for worker routing and concurrency control';

COMMENT ON COLUMN app_jobs.jobs.task_identifier IS 'Identifier for the task type (maps to a worker handler function)';

COMMENT ON COLUMN app_jobs.jobs.payload IS 'JSON payload of arguments passed to the task handler';

COMMENT ON COLUMN app_jobs.jobs.priority IS 'Execution priority; lower numbers run first (default 0)';

COMMENT ON COLUMN app_jobs.jobs.run_at IS 'Earliest time this job should be executed; used for delayed/scheduled execution';

COMMENT ON COLUMN app_jobs.jobs.attempts IS 'Number of times this job has been attempted so far';

COMMENT ON COLUMN app_jobs.jobs.max_attempts IS 'Maximum retry attempts before the job is considered permanently failed';

COMMENT ON COLUMN app_jobs.jobs.key IS 'Optional unique deduplication key; prevents duplicate jobs with the same key';

COMMENT ON COLUMN app_jobs.jobs.last_error IS 'Error message from the most recent failed attempt';

COMMENT ON COLUMN app_jobs.jobs.locked_at IS 'Timestamp when a worker locked this job for processing';

COMMENT ON COLUMN app_jobs.jobs.locked_by IS 'Identifier of the worker that currently holds the lock';

COMMENT ON COLUMN app_jobs.jobs.deferred_at IS 'When a worker first handed this job back unstarted because its function had no active deployment (defer_jobs_for_worker); bounds how long the job may keep waiting. NULL when never deferred';

ALTER TABLE app_jobs.jobs 
  ADD COLUMN created_at timestamptz;

ALTER TABLE app_jobs.jobs 
  ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE app_jobs.jobs 
  ADD COLUMN updated_at timestamptz;

ALTER TABLE app_jobs.jobs 
  ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER _100_update_jobs_modtime_tg
  BEFORE INSERT OR UPDATE
  ON app_jobs.jobs
  FOR EACH ROW
  EXECUTE PROCEDURE app_jobs.tg_update_timestamps();

CREATE FUNCTION app_jobs.tg_increase_job_queue_count() RETURNS trigger AS $EOFCODE$
BEGIN
  INSERT INTO app_jobs.job_queues (queue_name, job_count)
    VALUES (NEW.queue_name, 1)
  ON CONFLICT (queue_name)
    DO UPDATE SET
      job_count = job_queues.job_count + 1;
  RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER _500_increase_job_queue_count_on_insert
  AFTER INSERT
  ON app_jobs.jobs
  FOR EACH ROW
  WHEN (new.queue_name IS NOT NULL)
  EXECUTE PROCEDURE app_jobs.tg_increase_job_queue_count();

CREATE TRIGGER _500_increase_job_queue_count_on_update
  AFTER UPDATE OF queue_name
  ON app_jobs.jobs
  FOR EACH ROW
  WHEN (new.queue_name IS DISTINCT FROM old.queue_name
    AND new.queue_name IS NOT NULL)
  EXECUTE PROCEDURE app_jobs.tg_increase_job_queue_count();

CREATE TRIGGER _900_notify_worker
  AFTER INSERT
  ON app_jobs.jobs
  FOR EACH ROW
  EXECUTE PROCEDURE app_jobs.do_notify('jobs:insert');

CREATE FUNCTION app_jobs.tg_decrease_job_queue_count() RETURNS trigger AS $EOFCODE$
DECLARE
  v_new_job_count int;
BEGIN
  UPDATE
    app_jobs.job_queues
  SET
    job_count = job_queues.job_count - 1
  WHERE
    queue_name = OLD.queue_name
  RETURNING
    job_count INTO v_new_job_count;
  IF v_new_job_count <= 0 THEN
    DELETE FROM app_jobs.job_queues
    WHERE queue_name = OLD.queue_name
      AND job_count <= 0;
  END IF;
  RETURN OLD;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER decrease_job_queue_count_on_delete
  AFTER DELETE
  ON app_jobs.jobs
  FOR EACH ROW
  WHEN (old.queue_name IS NOT NULL)
  EXECUTE PROCEDURE app_jobs.tg_decrease_job_queue_count();

CREATE TRIGGER decrease_job_queue_count_on_update
  AFTER UPDATE OF queue_name
  ON app_jobs.jobs
  FOR EACH ROW
  WHEN (new.queue_name IS DISTINCT FROM old.queue_name
    AND old.queue_name IS NOT NULL)
  EXECUTE PROCEDURE app_jobs.tg_decrease_job_queue_count();

CREATE INDEX priority_run_at_id_idx ON app_jobs.jobs (priority, run_at, id);

CREATE INDEX jobs_locked_by_idx ON app_jobs.jobs (locked_by);

GRANT SELECT, INSERT, UPDATE, DELETE ON app_jobs.jobs TO administrator;

CREATE TABLE app_jobs.job_queues (
  queue_name text NOT NULL PRIMARY KEY,
  job_count int DEFAULT 0 NOT NULL,
  locked_at timestamptz,
  locked_by text
);

ALTER TABLE app_jobs.job_queues 
  SET (fillfactor = 50, autovacuum_vacuum_scale_factor = 0.01, autovacuum_vacuum_cost_delay = 0);

COMMENT ON TABLE app_jobs.job_queues IS 'Queue metadata: tracks job counts and locking state for each named queue';

COMMENT ON COLUMN app_jobs.job_queues.queue_name IS 'Unique name identifying this queue';

COMMENT ON COLUMN app_jobs.job_queues.job_count IS 'Number of pending jobs in this queue';

COMMENT ON COLUMN app_jobs.job_queues.locked_at IS 'Timestamp when this queue was locked for batch processing';

COMMENT ON COLUMN app_jobs.job_queues.locked_by IS 'Identifier of the worker that currently holds the queue lock';

GRANT SELECT, INSERT, UPDATE, DELETE ON app_jobs.job_queues TO administrator;

CREATE FUNCTION app_jobs.run_scheduled_job(
  id bigint,
  job_expiry interval DEFAULT '1 hours'
) RETURNS app_jobs.jobs AS $EOFCODE$
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
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION app_jobs.reschedule_jobs(
  job_ids bigint[],
  run_at timestamptz DEFAULT NULL,
  priority int DEFAULT NULL,
  attempts int DEFAULT NULL,
  max_attempts int DEFAULT NULL
) RETURNS SETOF app_jobs.jobs LANGUAGE sql AS $EOFCODE$
  UPDATE
    app_jobs.jobs
  SET
    run_at = coalesce(reschedule_jobs.run_at, jobs.run_at),
    priority = coalesce(reschedule_jobs.priority, jobs.priority),
    attempts = coalesce(reschedule_jobs.attempts, jobs.attempts),
    max_attempts = coalesce(reschedule_jobs.max_attempts, jobs.max_attempts)
  WHERE
    id = ANY (job_ids)
    AND (locked_by IS NULL
      OR locked_at < NOW() - interval '4 hours')
  RETURNING
    *;
$EOFCODE$;

CREATE FUNCTION app_jobs.release_jobs(
  worker_id text
) RETURNS void AS $EOFCODE$
DECLARE
BEGIN
  -- clear the job
  UPDATE
    app_jobs.jobs
  SET
    locked_at = NULL,
    locked_by = NULL,
    attempts = GREATEST (attempts - 1, 0)
  WHERE
    locked_by = worker_id;
  -- clear the queue
  UPDATE
    app_jobs.job_queues
  SET
    locked_at = NULL,
    locked_by = NULL
  WHERE
    locked_by = worker_id;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION app_jobs.permanently_fail_jobs(
  job_ids bigint[],
  error_message text DEFAULT NULL
) RETURNS SETOF app_jobs.jobs LANGUAGE sql AS $EOFCODE$
  UPDATE
    app_jobs.jobs
  SET
    last_error = coalesce(error_message, 'Manually marked as failed'),
    attempts = max_attempts
  WHERE
    id = ANY (job_ids)
    AND (locked_by IS NULL
      OR locked_at < NOW() - interval '4 hours')
  RETURNING
    *;
$EOFCODE$;

CREATE FUNCTION app_jobs.get_job(
  worker_id text,
  task_identifiers text[] DEFAULT NULL,
  job_expiry interval DEFAULT '4 hours'
) RETURNS app_jobs.jobs LANGUAGE plpgsql AS $EOFCODE$
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
$EOFCODE$;

CREATE FUNCTION app_jobs.fail_job(
  worker_id text,
  job_id bigint,
  error_message text
) RETURNS app_jobs.jobs LANGUAGE plpgsql STRICT AS $EOFCODE$
DECLARE
  v_row app_jobs.jobs;
BEGIN
  UPDATE
    app_jobs.jobs
  SET
    last_error = error_message,
    deferred_at = NULL,
    run_at = greatest (now(), run_at) + (exp(least (attempts, 10))::text || ' seconds')::interval,
    locked_by = NULL,
    locked_at = NULL
  WHERE
    id = job_id
    AND locked_by = worker_id
  RETURNING
    * INTO v_row;
  IF v_row.queue_name IS NOT NULL THEN
    UPDATE
      app_jobs.job_queues
    SET
      locked_by = NULL,
      locked_at = NULL
    WHERE
      queue_name = v_row.queue_name
      AND locked_by = worker_id;
  END IF;
  RETURN v_row;
END;
$EOFCODE$;

CREATE FUNCTION app_jobs.complete_jobs(
  job_ids bigint[]
) RETURNS SETOF app_jobs.jobs LANGUAGE sql AS $EOFCODE$
  DELETE FROM app_jobs.jobs
  WHERE id = ANY (job_ids)
    AND (locked_by IS NULL
      OR locked_at < NOW() - interval '4 hours')
  RETURNING
    *;
$EOFCODE$;

CREATE FUNCTION app_jobs.complete_job(
  worker_id text,
  job_id bigint
) RETURNS app_jobs.jobs LANGUAGE plpgsql AS $EOFCODE$
DECLARE
  v_row app_jobs.jobs;
BEGIN
  DELETE FROM app_jobs.jobs
  WHERE id = job_id
    AND locked_by = worker_id
  RETURNING
    * INTO v_row;
  IF v_row.queue_name IS NOT NULL THEN
    UPDATE
      app_jobs.job_queues
    SET
      locked_by = NULL,
      locked_at = NULL
    WHERE
      queue_name = v_row.queue_name
      AND locked_by = worker_id;
  END IF;
  RETURN v_row;
END;
$EOFCODE$;

CREATE FUNCTION app_jobs.add_scheduled_job(
  identifier text,
  payload pg_catalog.json DEFAULT '{}'::json,
  schedule_info pg_catalog.json DEFAULT '{}'::json,
  job_key text DEFAULT NULL,
  queue_name text DEFAULT NULL,
  max_attempts int DEFAULT 25,
  priority int DEFAULT 0
) RETURNS app_jobs.scheduled_jobs AS $EOFCODE$
DECLARE
  v_job app_jobs.scheduled_jobs;
BEGIN
  IF job_key IS NOT NULL THEN

    -- Upsert job	
    INSERT INTO app_jobs.scheduled_jobs (task_identifier, payload, queue_name, schedule_info, max_attempts, KEY, priority)	
      VALUES (identifier, coalesce(payload, '{}'::json), queue_name, schedule_info, coalesce(max_attempts, 25), job_key, coalesce(priority, 0))	
    ON CONFLICT (KEY)	
      DO UPDATE SET	
        task_identifier = excluded.task_identifier,
        payload = excluded.payload,
        queue_name = excluded.queue_name,
        max_attempts = excluded.max_attempts,
        schedule_info = excluded.schedule_info,
        priority = excluded.priority
      RETURNING	
        * INTO v_job;	

    RETURN v_job;
  END IF;

  INSERT INTO app_jobs.scheduled_jobs (task_identifier, payload, queue_name, schedule_info, max_attempts, priority)
    VALUES (identifier, payload, queue_name, schedule_info, max_attempts, priority)
  RETURNING
    * INTO v_job;
  RETURN v_job;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE FUNCTION app_jobs.add_job(
  identifier text,
  payload pg_catalog.json DEFAULT '{}'::json,
  job_key text DEFAULT NULL,
  queue_name text DEFAULT NULL,
  run_at timestamptz DEFAULT now(),
  max_attempts int DEFAULT 25,
  priority int DEFAULT 0
) RETURNS app_jobs.jobs AS $EOFCODE$
DECLARE
  v_job app_jobs.jobs;
BEGIN
  IF job_key IS NOT NULL THEN
    -- Upsert job	
    INSERT INTO app_jobs.jobs (task_identifier, payload, queue_name, run_at, max_attempts, KEY, priority)	
      VALUES (identifier, coalesce(payload, '{}'::json), queue_name, coalesce(run_at, now()), coalesce(max_attempts, 25), job_key, coalesce(priority, 0))	
    ON CONFLICT (KEY)	
      DO UPDATE SET	
        task_identifier = excluded.task_identifier, payload = excluded.payload, queue_name = excluded.queue_name, max_attempts = excluded.max_attempts, run_at = excluded.run_at, priority = excluded.priority,	
        -- always reset error/retry state	
        attempts = 0, last_error = NULL	
      WHERE	
        jobs.locked_at IS NULL	
      RETURNING	
        * INTO v_job;	

    -- If upsert succeeded (insert or update), return early	
    
    IF NOT (v_job IS NULL) THEN	
      RETURN v_job;	
    END IF;	

    -- Upsert failed -> there must be an existing job that is locked. Remove	
    -- existing key to allow a new one to be inserted, and prevent any	
    -- subsequent retries by bumping attempts to the max allowed.

    UPDATE	
      app_jobs.jobs	
    SET	
      KEY = NULL,	
      attempts = jobs.max_attempts	
    WHERE	
      KEY = job_key;	
  END IF;

  INSERT INTO app_jobs.jobs (task_identifier, payload, queue_name, run_at, max_attempts, priority)
    VALUES (identifier, payload, queue_name, run_at, max_attempts, priority)
  RETURNING
    * INTO v_job;
  RETURN v_job;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION app_jobs.add_job(text, pg_catalog.json, text, text, timestamptz, int, int) TO authenticated;

CREATE FUNCTION app_jobs.cron_field_values(
  field text,
  low int,
  high int,
  names text[] DEFAULT NULL
) RETURNS int[] AS $EOFCODE$
DECLARE
  part text;
  base text;
  step int;
  range_low int;
  range_high int;
  bounds text[];
  values int[] := '{}';
BEGIN
  IF field IS NULL OR field = '' THEN
    PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('field', field), 'public');
  END IF;

  FOREACH part IN ARRAY string_to_array(field, ',') LOOP
    step := 1;
    base := part;
    IF position('/' IN part) > 0 THEN
      base := split_part(part, '/', 1);
      IF split_part(part, '/', 2) !~ '^\d+$' OR split_part(part, '/', 2)::int < 1 THEN
        PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('field', field), 'public');
      END IF;
      step := split_part(part, '/', 2)::int;
    END IF;

    IF base IN ('*', '?') THEN
      range_low := low;
      range_high := high;
    ELSE
      bounds := string_to_array(base, '-');
      IF array_length(bounds, 1) > 2 THEN
        PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('field', field), 'public');
      END IF;
      range_low := app_jobs.cron_field_token(bounds[1], low, names);
      IF array_length(bounds, 1) = 2 THEN
        range_high := app_jobs.cron_field_token(bounds[2], low, names);
      ELSIF position('/' IN part) > 0 THEN
        -- "5/15" means every 15 starting at 5
        range_high := high;
      ELSE
        range_high := range_low;
      END IF;
    END IF;

    IF range_low IS NULL OR range_high IS NULL OR range_low < low OR range_high > high OR range_low > range_high THEN
      PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('field', field), 'public');
    END IF;

    values := values || ARRAY (
      SELECT
        generate_series(range_low, range_high, step));
  END LOOP;

  RETURN ARRAY (
    SELECT DISTINCT
      v
    FROM
      unnest(values) AS v
    ORDER BY
      v);
END;
$EOFCODE$ LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION app_jobs.cron_field_token(
  token text,
  low int,
  names text[]
) RETURNS int AS $EOFCODE$
DECLARE
  idx int;
BEGIN
  IF token ~ '^\d+$' THEN
    RETURN token::int;
  END IF;
  IF names IS NOT NULL THEN
    idx := array_position(names, upper(token));
    IF idx IS NOT NULL THEN
      RETURN low + idx - 1;
    END IF;
  END IF;
  RETURN NULL;
END;
$EOFCODE$ LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION app_jobs.schedule_next_run(
  schedule_info pg_catalog.json,
  after timestamptz DEFAULT now()
) RETURNS timestamptz AS $EOFCODE$
DECLARE
  rule text;
  fields text[];
  seconds int[];
  minutes int[];
  hours int[];
  days int[];
  months int[];
  dows int[];
  dom_any boolean;
  dow_any boolean;
  day_ok boolean;
  clock timestamp;
  not_before timestamptz;
  not_after timestamptz;
  steps int := 0;
  month_names constant text[] := ARRAY['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  dow_names constant text[] := ARRAY['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
BEGIN
  IF schedule_info IS NULL OR after IS NULL THEN
    RETURN NULL;
  END IF;

  rule := schedule_info ->> 'rule';

  IF rule IS NOT NULL THEN
    fields := regexp_split_to_array(trim(rule), '\s+');
    IF array_length(fields, 1) = 5 THEN
      fields := array_prepend('0', fields);
    ELSIF array_length(fields, 1) <> 6 THEN
      PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('rule', rule), 'public');
    END IF;
    seconds := app_jobs.cron_field_values(fields[1], 0, 59);
    minutes := app_jobs.cron_field_values(fields[2], 0, 59);
    hours := app_jobs.cron_field_values(fields[3], 0, 23);
    days := app_jobs.cron_field_values(fields[4], 1, 31);
    months := app_jobs.cron_field_values(fields[5], 1, 12, month_names);
    -- 7 is Sunday too
    dows := app_jobs.cron_field_values(fields[6], 0, 7, dow_names);
    dom_any := fields[4] IN ('*', '?');
    dow_any := fields[6] IN ('*', '?');
  ELSIF json_typeof(schedule_info) = 'object' THEN
    -- a node-schedule RecurrenceRule; every field unrestricted except second,
    -- which defaults to 0, so {} is "every minute"
    seconds := coalesce(app_jobs.recurrence_field_values(schedule_info -> 'second', 0, 59), ARRAY[0]);
    minutes := coalesce(app_jobs.recurrence_field_values(schedule_info -> 'minute', 0, 59), app_jobs.cron_field_values('*', 0, 59));
    hours := coalesce(app_jobs.recurrence_field_values(schedule_info -> 'hour', 0, 23), app_jobs.cron_field_values('*', 0, 23));
    days := coalesce(app_jobs.recurrence_field_values(schedule_info -> 'date', 1, 31), app_jobs.cron_field_values('*', 1, 31));
    months := coalesce((
      SELECT
        array_agg(m + 1 ORDER BY m)
      FROM
        unnest(app_jobs.recurrence_field_values(schedule_info -> 'month', 0, 11)) AS m), app_jobs.cron_field_values('*', 1, 12));
    dows := coalesce(app_jobs.recurrence_field_values(schedule_info -> 'dayOfWeek', 0, 6), app_jobs.cron_field_values('*', 0, 6));
    dom_any := app_jobs.recurrence_field_values(schedule_info -> 'date', 1, 31) IS NULL;
    dow_any := app_jobs.recurrence_field_values(schedule_info -> 'dayOfWeek', 0, 6) IS NULL;
  ELSE
    PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('schedule_info', schedule_info::jsonb), 'public');
  END IF;

  IF 7 = ANY (dows) THEN
    dows := ARRAY (
      SELECT DISTINCT
        CASE WHEN d = 7 THEN 0 ELSE d END
      FROM
        unnest(dows) AS d
      ORDER BY
        1);
  END IF;

  not_before := greatest(after, (schedule_info ->> 'start')::timestamptz);
  not_after := (schedule_info ->> 'end')::timestamptz;
  clock := date_trunc('second', not_before AT TIME ZONE 'UTC') + interval '1 second';

  LOOP
    steps := steps + 1;
    -- every branch below advances at least one unit; 5 years of month/day
    -- skipping plus the intra-day search is far below this bound
    IF steps > 100000 THEN
      PERFORM errors.raise_error('SCHEDULE_RULE_UNSATISFIABLE', jsonb_build_object('schedule_info', schedule_info::jsonb), 'public');
    END IF;

    IF NOT (extract(month FROM clock)::int = ANY (months)) THEN
      clock := date_trunc('month', clock) + interval '1 month';
      CONTINUE;
    END IF;

    day_ok := (dom_any AND dow_any)
      OR (NOT dom_any AND extract(day FROM clock)::int = ANY (days))
      OR (NOT dow_any AND extract(dow FROM clock)::int = ANY (dows));
    IF NOT day_ok THEN
      clock := date_trunc('day', clock) + interval '1 day';
      CONTINUE;
    END IF;

    IF NOT (extract(hour FROM clock)::int = ANY (hours)) THEN
      clock := date_trunc('hour', clock) + interval '1 hour';
      CONTINUE;
    END IF;

    IF NOT (extract(minute FROM clock)::int = ANY (minutes)) THEN
      clock := date_trunc('minute', clock) + interval '1 minute';
      CONTINUE;
    END IF;

    IF NOT (extract(second FROM clock)::int = ANY (seconds)) THEN
      clock := clock + interval '1 second';
      CONTINUE;
    END IF;

    IF not_after IS NOT NULL AND clock AT TIME ZONE 'UTC' > not_after THEN
      RETURN NULL;
    END IF;
    RETURN clock AT TIME ZONE 'UTC';
  END LOOP;
END;
$EOFCODE$ LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION app_jobs.recurrence_field_values(
  value pg_catalog.json,
  low int,
  high int
) RETURNS int[] AS $EOFCODE$
DECLARE
  item json;
  values int[] := '{}';
  range_low int;
  range_high int;
  step int;
BEGIN
  IF value IS NULL OR json_typeof(value) = 'null' THEN
    RETURN NULL;
  END IF;

  FOR item IN
  SELECT
    *
  FROM
    json_array_elements(
      CASE WHEN json_typeof(value) = 'array' THEN
        value
      ELSE
        json_build_array(value)
      END) LOOP
    IF json_typeof(item) = 'number' THEN
      range_low := (item #>> '{}')::numeric::int;
      range_high := range_low;
      step := 1;
    ELSIF json_typeof(item) = 'object' AND item -> 'start' IS NOT NULL THEN
      range_low := (item ->> 'start')::numeric::int;
      range_high := coalesce((item ->> 'end')::numeric::int, high);
      step := coalesce((item ->> 'step')::numeric::int, 1);
    ELSE
      PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('value', value::jsonb), 'public');
    END IF;

    IF range_low < low OR range_high > high OR range_low > range_high OR step < 1 THEN
      PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('value', value::jsonb), 'public');
    END IF;

    values := values || ARRAY (
      SELECT
        generate_series(range_low, range_high, step));
  END LOOP;

  RETURN ARRAY (
    SELECT DISTINCT
      v
    FROM
      unnest(values) AS v
    ORDER BY
      v);
END;
$EOFCODE$ LANGUAGE plpgsql IMMUTABLE;

CREATE INDEX scheduled_jobs_next_run_at_idx ON app_jobs.scheduled_jobs (next_run_at);

CREATE FUNCTION app_jobs.tg_stamp_next_run() RETURNS trigger AS $EOFCODE$
BEGIN
  NEW.next_run_at := app_jobs.schedule_next_run(NEW.schedule_info, now());
  RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER _100_stamp_next_run
  BEFORE INSERT OR UPDATE OF schedule_info
  ON app_jobs.scheduled_jobs
  FOR EACH ROW
  EXECUTE PROCEDURE app_jobs.tg_stamp_next_run();

CREATE FUNCTION app_jobs.fire_due_scheduled_jobs(
  batch_size int DEFAULT 200
) RETURNS jsonb AS $EOFCODE$
DECLARE
  sched app_jobs.scheduled_jobs;
  spawned app_jobs.jobs;
  fired int := 0;
  skipped int := 0;
  failed int := 0;
  error_message text;
  error_detail text;
BEGIN
  IF batch_size IS NULL OR batch_size <= 0 THEN
    PERFORM errors.raise_error('SCHEDULE_BATCH_SIZE_INVALID', jsonb_build_object('batch_size', batch_size), 'public');
  END IF;

  FOR sched IN
  SELECT
    s.*
  FROM
    app_jobs.scheduled_jobs AS s
  WHERE
    s.next_run_at <= now()
  ORDER BY
    s.next_run_at,
    s.id
  LIMIT batch_size
  FOR UPDATE
    SKIP LOCKED LOOP
      BEGIN
        spawned := app_jobs.run_scheduled_job(sched.id);
        fired := fired + 1;
        UPDATE
          app_jobs.scheduled_jobs
        SET
          last_error = NULL,
          last_error_at = NULL
        WHERE
          id = sched.id
          AND last_error IS NOT NULL;
      EXCEPTION
        WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS error_message = MESSAGE_TEXT,
          error_detail = PG_EXCEPTION_DETAIL;
          IF error_message = 'ALREADY_SCHEDULED' THEN
            skipped := skipped + 1;
          ELSE
            failed := failed + 1;
            RAISE WARNING 'fire_due_scheduled_jobs: schedule % (%) failed to spawn: % %', sched.id, sched.task_identifier, error_message, error_detail;
            UPDATE
              app_jobs.scheduled_jobs
            SET
              last_error = concat_ws(' ', error_message, nullif(error_detail, '')),
              last_error_at = now()
            WHERE
              id = sched.id;
          END IF;
      END;
    -- the fire trigger may have deleted a one-shot schedule; then there is
    -- nothing to advance
    UPDATE
      app_jobs.scheduled_jobs
    SET
      next_run_at = app_jobs.schedule_next_run(schedule_info, now())
    WHERE
      id = sched.id;
  END LOOP;

  RETURN jsonb_build_object('fired', fired, 'skipped', skipped, 'failed', failed, 'processed', fired + skipped + failed);
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE TABLE app_jobs.scheduled_task_holds (
  task_identifier text PRIMARY KEY,
  reason text,
  held_at timestamptz DEFAULT now() NOT NULL,
  CHECK (length(task_identifier) < 127)
);

COMMENT ON TABLE app_jobs.scheduled_task_holds IS 'Task identifiers whose recurring schedules are held dormant: their scheduled_jobs rows keep next_run_at NULL and spawn no jobs until released';

COMMENT ON COLUMN app_jobs.scheduled_task_holds.task_identifier IS 'Task identifier whose schedules are held';

COMMENT ON COLUMN app_jobs.scheduled_task_holds.reason IS 'Why the task is held, as reported by whoever placed the hold';

COMMENT ON COLUMN app_jobs.scheduled_task_holds.held_at IS 'When the hold was first placed';

GRANT SELECT, INSERT, UPDATE, DELETE ON app_jobs.scheduled_task_holds TO administrator;

CREATE FUNCTION app_jobs.tg_hold_next_run() RETURNS trigger AS $EOFCODE$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM app_jobs.scheduled_task_holds AS h
    WHERE h.task_identifier = NEW.task_identifier
  ) THEN
    NEW.next_run_at := NULL;
  END IF;
  RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER _110_hold_next_run
  BEFORE INSERT OR UPDATE OF schedule_info
  ON app_jobs.scheduled_jobs
  FOR EACH ROW
  EXECUTE PROCEDURE app_jobs.tg_hold_next_run();

CREATE FUNCTION app_jobs.hold_scheduled_task(
  task_identifier text,
  reason text DEFAULT NULL
) RETURNS int AS $EOFCODE$
DECLARE
  dormant integer;
BEGIN
  IF hold_scheduled_task.task_identifier IS NULL THEN
    PERFORM errors.raise_error('SCHEDULED_TASK_IDENTIFIER_REQUIRED', '{}'::jsonb, 'public');
  END IF;

  INSERT INTO app_jobs.scheduled_task_holds AS h (task_identifier, reason)
  VALUES (hold_scheduled_task.task_identifier, hold_scheduled_task.reason)
  ON CONFLICT ON CONSTRAINT scheduled_task_holds_pkey
    DO UPDATE SET
      reason = EXCLUDED.reason;

  UPDATE
    app_jobs.scheduled_jobs AS s
  SET
    next_run_at = NULL
  WHERE
    s.task_identifier = hold_scheduled_task.task_identifier
    AND s.next_run_at IS NOT NULL;
  GET DIAGNOSTICS dormant = ROW_COUNT;

  RETURN dormant;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION app_jobs.release_scheduled_task(
  task_identifier text
) RETURNS int AS $EOFCODE$
DECLARE
  woken integer;
BEGIN
  IF release_scheduled_task.task_identifier IS NULL THEN
    PERFORM errors.raise_error('SCHEDULED_TASK_IDENTIFIER_REQUIRED', '{}'::jsonb, 'public');
  END IF;

  DELETE FROM app_jobs.scheduled_task_holds AS h
  WHERE h.task_identifier = release_scheduled_task.task_identifier;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  WITH restamped AS (
    UPDATE
      app_jobs.scheduled_jobs AS s
    SET
      next_run_at = app_jobs.schedule_next_run(s.schedule_info, now())
    WHERE
      s.task_identifier = release_scheduled_task.task_identifier
      AND s.next_run_at IS NULL
    RETURNING
      s.next_run_at
  )
  SELECT
    count(*) INTO woken
  FROM
    restamped AS r
  WHERE
    r.next_run_at IS NOT NULL;

  RETURN woken;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE INDEX job_queues_locked_idx ON app_jobs.job_queues (queue_name) WHERE locked_at IS NOT NULL;

CREATE INDEX jobs_queue_head_idx ON app_jobs.jobs (queue_name, priority, run_at, id) WHERE queue_name IS NOT NULL;

CREATE FUNCTION app_jobs.get_jobs(
  worker_id text,
  task_identifiers text[] DEFAULT NULL,
  n int DEFAULT 1,
  job_expiry interval DEFAULT '4 hours'
) RETURNS SETOF app_jobs.jobs LANGUAGE plpgsql AS $EOFCODE$
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
$EOFCODE$;

CREATE FUNCTION app_jobs.complete_jobs_for_worker(
  worker_id text,
  job_ids bigint[]
) RETURNS SETOF app_jobs.jobs LANGUAGE plpgsql AS $EOFCODE$
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
$EOFCODE$;

CREATE FUNCTION app_jobs.fail_jobs_for_worker(
  worker_id text,
  job_ids bigint[],
  error_messages text[]
) RETURNS SETOF app_jobs.jobs LANGUAGE plpgsql AS $EOFCODE$
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
$EOFCODE$;

CREATE FUNCTION app_jobs.defer_jobs_for_worker(
  worker_id text,
  job_ids bigint[],
  reasons text[]
) RETURNS SETOF app_jobs.jobs LANGUAGE plpgsql AS $EOFCODE$
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
$EOFCODE$;