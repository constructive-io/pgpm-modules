\echo Use "CREATE EXTENSION launchql-meta" to load this file. \quit
CREATE SCHEMA meta_public;

GRANT USAGE ON SCHEMA meta_public TO authenticated;

GRANT USAGE ON SCHEMA meta_public TO anonymous;

CREATE SCHEMA meta_private;

GRANT USAGE ON SCHEMA meta_private TO authenticated;

GRANT USAGE ON SCHEMA meta_private TO anonymous;

CREATE SCHEMA meta_jobs;

GRANT USAGE ON SCHEMA meta_jobs TO authenticated;

GRANT USAGE ON SCHEMA meta_jobs TO anonymous;

CREATE SCHEMA IF NOT EXISTS meta_jobs;

GRANT USAGE ON SCHEMA meta_jobs TO administrator;

ALTER DEFAULT PRIVILEGES IN SCHEMA meta_jobs 
 GRANT EXECUTE ON FUNCTIONS  TO administrator;

CREATE FUNCTION meta_jobs.json_build_object_apply ( arguments text[] ) RETURNS json AS $EOFCODE$
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

CREATE TABLE meta_jobs.jobs (
 	id bigserial PRIMARY KEY,
	queue_name text DEFAULT ( public.gen_random_uuid()::text ),
	task_identifier text NOT NULL,
	payload json DEFAULT ( '{}'::json ) NOT NULL,
	priority int DEFAULT ( 0 ) NOT NULL,
	run_at timestamptz DEFAULT ( now() ) NOT NULL,
	attempts int DEFAULT ( 0 ) NOT NULL,
	max_attempts int DEFAULT ( 25 ) NOT NULL,
	key text,
	last_error text,
	locked_at timestamptz,
	locked_by text,
	CHECK ( length(key) < 513 ),
	CHECK ( length(task_identifier) < 127 ),
	CHECK ( max_attempts > 0 ),
	CHECK ( length(queue_name) < 127 ),
	CHECK ( length(locked_by) > 3 ),
	UNIQUE ( key ) 
);

CREATE TABLE meta_jobs.job_queues (
 	queue_name text NOT NULL PRIMARY KEY,
	job_count int DEFAULT ( 0 ) NOT NULL,
	locked_at timestamptz,
	locked_by text 
);

CREATE FUNCTION meta_jobs.add_job ( identifier text, payload json DEFAULT '{}'::json, job_key text DEFAULT NULL, queue_name text DEFAULT NULL, run_at timestamptz DEFAULT now(), max_attempts int DEFAULT 25, priority int DEFAULT 0 ) RETURNS meta_jobs.jobs AS $EOFCODE$
DECLARE
  v_job "meta_jobs".jobs;
BEGIN
  IF job_key IS NOT NULL THEN
    INSERT INTO "meta_jobs".jobs (task_identifier, payload, queue_name, run_at, max_attempts, KEY, priority)
      VALUES (identifier, coalesce(payload, '{}'::json), queue_name, coalesce(run_at, now()), coalesce(max_attempts, 25), job_key, coalesce(priority, 0))
    ON CONFLICT (KEY)
      DO UPDATE SET
        task_identifier = excluded.task_identifier, payload = excluded.payload, queue_name = excluded.queue_name, max_attempts = excluded.max_attempts, run_at = excluded.run_at, priority = excluded.priority,
        attempts = 0, last_error = NULL
      WHERE
        jobs.locked_at IS NULL
      RETURNING
        * INTO v_job;
    IF NOT (v_job IS NULL) THEN
      RETURN v_job;
    END IF;
    UPDATE
      "meta_jobs".jobs
    SET
      KEY = NULL,
      attempts = jobs.max_attempts
    WHERE
      KEY = job_key;
  END IF;
  INSERT INTO "meta_jobs".jobs (task_identifier, payload, queue_name, run_at, max_attempts, priority)
    VALUES (identifier, payload, queue_name, run_at, max_attempts, priority)
  RETURNING
    * INTO v_job;
  RETURN v_job;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE TABLE meta_jobs.scheduled_jobs (
 	id bigserial PRIMARY KEY,
	queue_name text DEFAULT ( public.gen_random_uuid()::text ),
	task_identifier text NOT NULL,
	payload json DEFAULT ( '{}'::json ) NOT NULL,
	priority int DEFAULT ( 0 ) NOT NULL,
	max_attempts int DEFAULT ( 25 ) NOT NULL,
	key text,
	locked_at timestamptz,
	locked_by text,
	schedule_info json NOT NULL,
	last_scheduled timestamptz,
	last_scheduled_id bigint,
	CHECK ( length(key) < 513 ),
	CHECK ( length(task_identifier) < 127 ),
	CHECK ( max_attempts > 0 ),
	CHECK ( length(queue_name) < 127 ),
	CHECK ( length(locked_by) > 3 ),
	UNIQUE ( key ) 
);

CREATE FUNCTION meta_jobs.add_scheduled_job ( identifier text, payload json DEFAULT '{}'::json, schedule_info json DEFAULT '{}'::json, job_key text DEFAULT NULL, queue_name text DEFAULT NULL, max_attempts int DEFAULT 25, priority int DEFAULT 0 ) RETURNS meta_jobs.scheduled_jobs AS $EOFCODE$
DECLARE
  v_job "meta_jobs".scheduled_jobs;
BEGIN
  IF job_key IS NOT NULL THEN
    INSERT INTO "meta_jobs".scheduled_jobs (task_identifier, payload, queue_name, schedule_info, max_attempts, KEY, priority)
      VALUES (identifier, coalesce(payload, '{}'::json), queue_name, schedule_info, coalesce(max_attempts, 25), job_key, coalesce(priority, 0))
    ON CONFLICT (KEY)
      DO UPDATE SET
        task_identifier = excluded.task_identifier, payload = excluded.payload, queue_name = excluded.queue_name, max_attempts = excluded.max_attempts, schedule_info = excluded.schedule_info, priority = excluded.priority
      WHERE
        scheduled_jobs.locked_at IS NULL
      RETURNING
        * INTO v_job;
    IF NOT (v_job IS NULL) THEN
      RETURN v_job;
    END IF;
    DELETE FROM "meta_jobs".scheduled_jobs
    WHERE KEY = job_key;
  END IF;
  INSERT INTO "meta_jobs".scheduled_jobs (task_identifier, payload, queue_name, schedule_info, max_attempts, priority)
    VALUES (identifier, payload, queue_name, schedule_info, max_attempts, priority)
  RETURNING
    * INTO v_job;
  RETURN v_job;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE FUNCTION meta_jobs.complete_job ( worker_id text, job_id bigint ) RETURNS meta_jobs.jobs LANGUAGE plpgsql AS $EOFCODE$
DECLARE
  v_row "meta_jobs".jobs;
BEGIN
  DELETE FROM "meta_jobs".jobs
  WHERE id = job_id
  RETURNING
    * INTO v_row;
  IF v_row.queue_name IS NOT NULL THEN
    UPDATE
      "meta_jobs".job_queues
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

CREATE FUNCTION meta_jobs.complete_jobs ( job_ids bigint[] ) RETURNS SETOF meta_jobs.jobs LANGUAGE sql AS $EOFCODE$
  DELETE FROM "meta_jobs".jobs
  WHERE id = ANY (job_ids)
    AND (locked_by IS NULL
      OR locked_at < NOW() - interval '4 hours')
  RETURNING
    *;
$EOFCODE$;

CREATE FUNCTION meta_jobs.do_notify (  ) RETURNS trigger AS $EOFCODE$
BEGIN
  PERFORM
    pg_notify(TG_ARGV[0], '');
  RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql;

CREATE FUNCTION meta_jobs.fail_job ( worker_id text, job_id bigint, error_message text ) RETURNS meta_jobs.jobs LANGUAGE plpgsql STRICT AS $EOFCODE$
DECLARE
  v_row "meta_jobs".jobs;
BEGIN
  UPDATE
    "meta_jobs".jobs
  SET
    last_error = error_message,
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
      "meta_jobs".job_queues
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

CREATE FUNCTION meta_jobs.get_job ( worker_id text, task_identifiers text[] DEFAULT NULL, job_expiry interval DEFAULT '4 hours' ) RETURNS meta_jobs.jobs LANGUAGE plpgsql AS $EOFCODE$
DECLARE
  v_job_id bigint;
  v_queue_name text;
  v_row "meta_jobs".jobs;
  v_now timestamptz = now();
BEGIN
  IF worker_id IS NULL THEN
    RAISE exception 'INVALID_WORKER_ID';
  END IF;
  SELECT
    jobs.queue_name,
    jobs.id INTO v_queue_name,
    v_job_id
  FROM
    "meta_jobs".jobs
  WHERE (jobs.locked_at IS NULL
    OR jobs.locked_at < (v_now - job_expiry))
    AND (jobs.queue_name IS NULL
      OR EXISTS (
        SELECT
          1
        FROM
          "meta_jobs".job_queues
        WHERE
          job_queues.queue_name = jobs.queue_name
          AND (job_queues.locked_at IS NULL
            OR job_queues.locked_at < (v_now - job_expiry))
        FOR UPDATE
          SKIP LOCKED))
    AND run_at <= v_now
    AND attempts < max_attempts
    AND (task_identifiers IS NULL
      OR task_identifier = ANY (task_identifiers))
  ORDER BY
    priority ASC,
    run_at ASC,
    id ASC
  LIMIT 1
  FOR UPDATE
    SKIP LOCKED;
  IF v_job_id IS NULL THEN
    RETURN NULL;
  END IF;
  IF v_queue_name IS NOT NULL THEN
    UPDATE
      "meta_jobs".job_queues
    SET
      locked_by = worker_id,
      locked_at = v_now
    WHERE
      job_queues.queue_name = v_queue_name;
  END IF;
  UPDATE
    "meta_jobs".jobs
  SET
    attempts = attempts + 1,
    locked_by = worker_id,
    locked_at = v_now
  WHERE
    id = v_job_id
  RETURNING
    * INTO v_row;
  RETURN v_row;
END;
$EOFCODE$;

CREATE FUNCTION meta_jobs.get_scheduled_job ( worker_id text, task_identifiers text[] DEFAULT NULL ) RETURNS meta_jobs.scheduled_jobs LANGUAGE plpgsql AS $EOFCODE$
DECLARE
  v_job_id bigint;
  v_row "meta_jobs".scheduled_jobs;
BEGIN
  IF worker_id IS NULL THEN
    RAISE exception 'INVALID_WORKER_ID';
  END IF;
  SELECT
    scheduled_jobs.id INTO v_job_id
  FROM
    "meta_jobs".scheduled_jobs
  WHERE (scheduled_jobs.locked_at IS NULL)
    AND (task_identifiers IS NULL
      OR task_identifier = ANY (task_identifiers))
  ORDER BY
    priority ASC,
    id ASC
  LIMIT 1
  FOR UPDATE
    SKIP LOCKED;
  IF v_job_id IS NULL THEN
    RETURN NULL;
  END IF;
  UPDATE
    "meta_jobs".scheduled_jobs
  SET
    locked_by = worker_id,
    locked_at = NOW()
  WHERE
    id = v_job_id
  RETURNING
    * INTO v_row;
  RETURN v_row;
END;
$EOFCODE$;

CREATE FUNCTION meta_jobs.permanently_fail_jobs ( job_ids bigint[], error_message text DEFAULT NULL ) RETURNS SETOF meta_jobs.jobs LANGUAGE sql AS $EOFCODE$
  UPDATE
    "meta_jobs".jobs
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

CREATE FUNCTION meta_jobs.release_jobs ( worker_id text ) RETURNS void AS $EOFCODE$
DECLARE
BEGIN
  UPDATE
    "meta_jobs".jobs
  SET
    locked_at = NULL,
    locked_by = NULL,
    attempts = GREATEST (attempts - 1, 0)
  WHERE
    locked_by = worker_id;
  UPDATE
    "meta_jobs".job_queues
  SET
    locked_at = NULL,
    locked_by = NULL
  WHERE
    locked_by = worker_id;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION meta_jobs.release_scheduled_jobs ( worker_id text, ids bigint[] DEFAULT NULL ) RETURNS void AS $EOFCODE$
DECLARE
BEGIN
  UPDATE
    "meta_jobs".scheduled_jobs s
  SET
    locked_at = NULL,
    locked_by = NULL
  WHERE
    locked_by = worker_id
    AND (ids IS NULL
      OR s.id = ANY (ids));
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION meta_jobs.reschedule_jobs ( job_ids bigint[], run_at timestamptz DEFAULT NULL, priority int DEFAULT NULL, attempts int DEFAULT NULL, max_attempts int DEFAULT NULL ) RETURNS SETOF meta_jobs.jobs LANGUAGE sql AS $EOFCODE$
  UPDATE
    "meta_jobs".jobs
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

CREATE FUNCTION meta_jobs.run_scheduled_job ( id bigint, job_expiry interval DEFAULT '1 hours' ) RETURNS meta_jobs.jobs AS $EOFCODE$
DECLARE
  j "meta_jobs".jobs;
  last_id bigint;
  lkd_by text;
BEGIN
  SELECT
    last_scheduled_id
  FROM
    "meta_jobs".scheduled_jobs s
  WHERE
    s.id = run_scheduled_job.id INTO last_id;
  IF (last_id IS NOT NULL) THEN
    SELECT
      locked_by
    FROM
      "meta_jobs".jobs js
    WHERE
      js.id = last_id
      AND (js.locked_at IS NULL -- never been run
        OR js.locked_at >= (NOW() - job_expiry)
) INTO lkd_by;
    IF (FOUND) THEN
      RAISE EXCEPTION 'ALREADY_SCHEDULED';
    END IF;
  END IF;
  INSERT INTO "meta_jobs".jobs (queue_name, task_identifier, payload, priority, max_attempts, KEY)
  SELECT
    queue_name,
    task_identifier,
    payload,
    priority,
    max_attempts,
    KEY
  FROM
    "meta_jobs".scheduled_jobs s
  WHERE
    s.id = run_scheduled_job.id
  RETURNING
    * INTO j;
  UPDATE
    "meta_jobs".scheduled_jobs s
  SET
    last_scheduled = NOW(),
    last_scheduled_id = j.id
  WHERE
    s.id = run_scheduled_job.id;
  RETURN j;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE meta_jobs.job_queues TO administrator;

CREATE INDEX job_queues_locked_by_idx ON meta_jobs.job_queues ( locked_by );

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE meta_jobs.jobs TO administrator;

CREATE INDEX jobs_locked_by_idx ON meta_jobs.jobs ( locked_by );

CREATE INDEX priority_run_at_id_idx ON meta_jobs.jobs ( priority, run_at, id );

CREATE FUNCTION meta_jobs.tg_decrease_job_queue_count (  ) RETURNS trigger AS $EOFCODE$
DECLARE
  v_new_job_count int;
BEGIN
  UPDATE
    "meta_jobs".job_queues
  SET
    job_count = job_queues.job_count - 1
  WHERE
    queue_name = OLD.queue_name
  RETURNING
    job_count INTO v_new_job_count;
  IF v_new_job_count <= 0 THEN
    DELETE FROM "meta_jobs".job_queues
    WHERE queue_name = OLD.queue_name
      AND job_count <= 0;
  END IF;
  RETURN OLD;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER decrease_job_queue_count_on_delete 
 AFTER DELETE ON meta_jobs.jobs 
 FOR EACH ROW
 WHEN ( OLD.queue_name IS NOT NULL ) 
 EXECUTE PROCEDURE meta_jobs. tg_decrease_job_queue_count (  );

CREATE TRIGGER decrease_job_queue_count_on_update 
 AFTER UPDATE OF queue_name ON meta_jobs.jobs 
 FOR EACH ROW
 WHEN ( new.queue_name IS DISTINCT FROM old.queue_name AND old.queue_name IS NOT NULL ) 
 EXECUTE PROCEDURE meta_jobs. tg_decrease_job_queue_count (  );

CREATE FUNCTION meta_jobs.tg_increase_job_queue_count (  ) RETURNS trigger AS $EOFCODE$
BEGIN
  INSERT INTO "meta_jobs".job_queues (queue_name, job_count)
    VALUES (NEW.queue_name, 1)
  ON CONFLICT (queue_name)
    DO UPDATE SET
      job_count = job_queues.job_count + 1;
  RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER _500_increase_job_queue_count_on_insert 
 AFTER INSERT ON meta_jobs.jobs 
 FOR EACH ROW
 WHEN ( NEW.queue_name IS NOT NULL ) 
 EXECUTE PROCEDURE meta_jobs. tg_increase_job_queue_count (  );

CREATE TRIGGER _500_increase_job_queue_count_on_update 
 AFTER UPDATE OF queue_name ON meta_jobs.jobs 
 FOR EACH ROW
 WHEN ( new.queue_name IS DISTINCT FROM old.queue_name AND new.queue_name IS NOT NULL ) 
 EXECUTE PROCEDURE meta_jobs. tg_increase_job_queue_count (  );

CREATE TRIGGER _900_notify_worker 
 AFTER INSERT ON meta_jobs.jobs 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_jobs. do_notify ( 'jobs:insert' );

CREATE FUNCTION meta_jobs.tg_update_timestamps (  ) RETURNS trigger AS $EOFCODE$
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

ALTER TABLE meta_jobs.jobs ADD COLUMN  created_at timestamptz;

ALTER TABLE meta_jobs.jobs ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE meta_jobs.jobs ADD COLUMN  updated_at timestamptz;

ALTER TABLE meta_jobs.jobs ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER _100_update_jobs_modtime_tg 
 BEFORE INSERT OR UPDATE ON meta_jobs.jobs 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_jobs. tg_update_timestamps (  );

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE meta_jobs.scheduled_jobs TO administrator;

CREATE INDEX scheduled_jobs_locked_by_idx ON meta_jobs.scheduled_jobs ( locked_by );

CREATE INDEX scheduled_jobs_priority_id_idx ON meta_jobs.scheduled_jobs ( priority, id );

CREATE TRIGGER _900_notify_scheduled_job 
 AFTER INSERT ON meta_jobs.scheduled_jobs 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_jobs. do_notify ( 'scheduled_jobs:insert' );

CREATE FUNCTION meta_jobs.trigger_job_with_fields (  ) RETURNS trigger AS $EOFCODE$
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
    "meta_jobs".add_job (fn, "meta_jobs".json_build_object_apply (args));
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    RETURN NEW;
  END IF;
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE FUNCTION meta_jobs.tg_add_job_with_row_id (  ) RETURNS trigger AS $EOFCODE$
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    PERFORM
      "meta_jobs".add_job (tg_argv[0], json_build_object('id', NEW.id));
    RETURN NEW;
  END IF;
  IF (TG_OP = 'DELETE') THEN
    PERFORM
      "meta_jobs".add_job (tg_argv[0], json_build_object('id', OLD.id));
    RETURN OLD;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION meta_jobs.tg_add_job_with_row_id IS E'Useful shortcut to create a job on insert or update. Pass the task name as the trigger argument, and the record id will automatically be available on the JSON payload.';

CREATE FUNCTION meta_jobs.tg_add_job_with_row (  ) RETURNS trigger AS $EOFCODE$
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    PERFORM
      "meta_jobs".add_job (TG_ARGV[0], to_json(NEW));
    RETURN NEW;
  END IF;
  IF (TG_OP = 'DELETE') THEN
    PERFORM
      "meta_jobs".add_job (TG_ARGV[0], to_json(OLD));
    RETURN OLD;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION meta_jobs.tg_add_job_with_row IS E'Useful shortcut to create a job on insert or update. Pass the task name as the trigger argument, and the record data will automatically be available on the JSON payload.';

CREATE FUNCTION meta_private.uuid_generate_v4 (  ) RETURNS uuid AS $EOFCODE$
DECLARE
    new_uuid char(36);
    md5_str char(32);
    md5_str2 char(32);
    uid text;
BEGIN
    md5_str := md5(concat(random(), now()));
    md5_str2 := md5(concat(random(), now()));
    
    new_uuid := concat(
        LEFT (md5('meta'), 2),
        LEFT (md5(concat(extract(year FROM now()), extract(week FROM now()))), 2),
        substring(md5_str, 1, 4),
        '-',
        substring(md5_str, 5, 4),
        '-4',
        substring(md5_str2, 9, 3),
        '-',
        substring(md5_str, 13, 4),
        '-', 
        substring(md5_str2, 17, 12)
    );
    RETURN new_uuid;
END;
$EOFCODE$ LANGUAGE plpgsql;

CREATE FUNCTION meta_private.uuid_generate_seeded_uuid ( seed text ) RETURNS uuid AS $EOFCODE$
DECLARE
    new_uuid char(36);
    md5_str char(32);
    md5_str2 char(32);
    uid text;
BEGIN
    md5_str := md5(concat(random(), now()));
    md5_str2 := md5(concat(random(), now()));
    
    new_uuid := concat(
        LEFT (md5(seed), 2),
        LEFT (md5(concat(extract(year FROM now()), extract(week FROM now()))), 2),
        substring(md5_str, 1, 4),
        '-',
        substring(md5_str, 5, 4),
        '-4',
        substring(md5_str2, 9, 3),
        '-',
        substring(md5_str, 13, 4),
        '-', 
        substring(md5_str2, 17, 12)
    );
    RETURN new_uuid;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION meta_private.seeded_uuid_related_trigger (  ) RETURNS trigger AS $EOFCODE$
DECLARE
    _seed_column text := to_json(NEW) ->> TG_ARGV[1];
BEGIN
    IF _seed_column IS NULL THEN
        RAISE EXCEPTION 'UUID seed is NULL on table %', TG_TABLE_NAME;
    END IF;
    NEW := NEW #= (TG_ARGV[0] || '=>' || "meta_private".uuid_generate_seeded_uuid(_seed_column))::hstore;
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION meta_private.uuid_generate_v4 TO PUBLIC;

GRANT EXECUTE ON FUNCTION meta_private.uuid_generate_seeded_uuid TO PUBLIC;

GRANT EXECUTE ON FUNCTION meta_private.seeded_uuid_related_trigger TO PUBLIC;

CREATE TABLE meta_public.users (
  
);

ALTER TABLE meta_public.users DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.users ADD COLUMN  id uuid;

ALTER TABLE meta_public.users ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.users ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.users ADD CONSTRAINT users_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.users ADD COLUMN  type int;

ALTER TABLE meta_public.users ALTER COLUMN type SET DEFAULT 0;

CREATE SCHEMA meta_simple_secrets;

GRANT USAGE ON SCHEMA meta_simple_secrets TO authenticated;

GRANT USAGE ON SCHEMA meta_simple_secrets TO anonymous;

CREATE TABLE meta_simple_secrets.user_secrets (
  
);

ALTER TABLE meta_simple_secrets.user_secrets DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_simple_secrets.user_secrets ADD COLUMN  id uuid;

ALTER TABLE meta_simple_secrets.user_secrets ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_simple_secrets.user_secrets ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_simple_secrets.user_secrets ADD COLUMN  user_id uuid;

ALTER TABLE meta_simple_secrets.user_secrets ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE meta_simple_secrets.user_secrets ADD COLUMN  name text;

ALTER TABLE meta_simple_secrets.user_secrets ALTER COLUMN name SET NOT NULL;

ALTER TABLE meta_simple_secrets.user_secrets ADD COLUMN  value text;

ALTER TABLE meta_simple_secrets.user_secrets ADD CONSTRAINT user_secrets_pkey PRIMARY KEY ( id );

ALTER TABLE meta_simple_secrets.user_secrets ADD CONSTRAINT user_secrets_user_id_name_key UNIQUE ( user_id, name );

CREATE FUNCTION meta_simple_secrets.get ( v_owner_id uuid, v_secret_name text, v_default_value text DEFAULT NULL ) RETURNS text AS $EOFCODE$
DECLARE
    val text;
BEGIN
    SELECT value FROM "meta_simple_secrets".user_secrets t 
        WHERE t.user_id = get.v_owner_id
        AND t.name = get.v_secret_name
    INTO val;
    IF (NOT FOUND OR val IS NULL) THEN
        RETURN v_default_value;
    END IF;
    RETURN val;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION meta_simple_secrets.get TO authenticated;

CREATE FUNCTION meta_simple_secrets.set ( v_owner_id uuid, v_secret_name text, v_value anyelement ) RETURNS void AS $EOFCODE$
    INSERT INTO "meta_simple_secrets".user_secrets 
        (user_id, name, value)
    VALUES
        (set.v_owner_id, set.v_secret_name, set.v_value::text)
    ON CONFLICT (user_id, name)
    DO UPDATE 
    SET value = EXCLUDED.value;
$EOFCODE$ LANGUAGE sql VOLATILE;

GRANT EXECUTE ON FUNCTION meta_simple_secrets.set TO authenticated;

CREATE FUNCTION meta_simple_secrets.del ( owner_id uuid, secret_name text ) RETURNS void AS $EOFCODE$
    DELETE FROM "meta_simple_secrets".user_secrets s 
        WHERE
        s.user_id = del.owner_id
        AND s.name = secret_name;
$EOFCODE$ LANGUAGE sql VOLATILE;

CREATE FUNCTION meta_simple_secrets.del ( owner_id uuid, secret_names text[] ) RETURNS void AS $EOFCODE$
    DELETE FROM "meta_simple_secrets".user_secrets s 
        WHERE
        s.user_id = del.owner_id
        AND s.name = ANY (secret_names);
$EOFCODE$ LANGUAGE sql VOLATILE;

GRANT EXECUTE ON FUNCTION meta_simple_secrets.del ( uuid,text ) TO authenticated;

GRANT EXECUTE ON FUNCTION meta_simple_secrets.del ( uuid,text[] ) TO authenticated;

CREATE TABLE meta_private.api_tokens (
  
);

ALTER TABLE meta_private.api_tokens DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_private.api_tokens ADD COLUMN  id uuid;

ALTER TABLE meta_private.api_tokens ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_private.api_tokens ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_private.api_tokens ADD COLUMN  user_id uuid;

ALTER TABLE meta_private.api_tokens ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE meta_private.api_tokens ADD COLUMN  access_token text;

ALTER TABLE meta_private.api_tokens ALTER COLUMN access_token SET NOT NULL;

ALTER TABLE meta_private.api_tokens ALTER COLUMN access_token SET DEFAULT encode(gen_random_bytes(48), 'hex');

ALTER TABLE meta_private.api_tokens ADD COLUMN  access_token_expires_at timestamptz;

ALTER TABLE meta_private.api_tokens ALTER COLUMN access_token_expires_at SET NOT NULL;

ALTER TABLE meta_private.api_tokens ALTER COLUMN access_token_expires_at SET DEFAULT now() + '30 days'::interval;

ALTER TABLE meta_private.api_tokens ADD CONSTRAINT api_tokens_pkey PRIMARY KEY ( id );

ALTER TABLE meta_private.api_tokens ADD CONSTRAINT api_tokens_access_token_key UNIQUE ( access_token );

CREATE INDEX api_tokens_user_id_idx ON meta_private.api_tokens ( user_id );

CREATE SCHEMA meta_encrypted_secrets;

GRANT USAGE ON SCHEMA meta_encrypted_secrets TO authenticated;

GRANT USAGE ON SCHEMA meta_encrypted_secrets TO anonymous;

CREATE TABLE meta_encrypted_secrets.user_encrypted_secrets (
  
);

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets ADD COLUMN  id uuid;

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets ADD COLUMN  user_id uuid;

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets ADD COLUMN  name text;

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets ALTER COLUMN name SET NOT NULL;

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets ADD COLUMN  value bytea;

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets ADD COLUMN  enc text;

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets ADD CONSTRAINT user_encrypted_secrets_pkey PRIMARY KEY ( id );

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets ADD CONSTRAINT user_encrypted_secrets_user_id_name_key UNIQUE ( user_id, name );

CREATE FUNCTION meta_encrypted_secrets.user_encrypted_secrets_hash (  ) RETURNS trigger AS $EOFCODE$
BEGIN
   
IF (NEW.enc = 'crypt') THEN
    NEW.value = crypt(NEW.value::text, gen_salt('bf'));
ELSIF (NEW.enc = 'pgp') THEN
    NEW.value = pgp_sym_encrypt(encode(NEW.value::bytea, 'hex'), NEW.user_id::text, 'compress-algo=1, cipher-algo=aes256');
ELSE
    NEW.enc = 'none';
END IF;
RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER user_encrypted_secrets_update_tg 
 BEFORE UPDATE ON meta_encrypted_secrets.user_encrypted_secrets 
 FOR EACH ROW
 WHEN ( NEW.value IS DISTINCT FROM OLD.value ) 
 EXECUTE PROCEDURE meta_encrypted_secrets. user_encrypted_secrets_hash (  );

CREATE TRIGGER user_encrypted_secrets_insert_tg 
 BEFORE INSERT ON meta_encrypted_secrets.user_encrypted_secrets 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_encrypted_secrets. user_encrypted_secrets_hash (  );

CREATE FUNCTION meta_encrypted_secrets.get ( user_id uuid, secret_name text, default_value text DEFAULT NULL ) RETURNS text AS $EOFCODE$
DECLARE
  v_secret "meta_encrypted_secrets".user_encrypted_secrets;
BEGIN
  SELECT
    *
  FROM
    "meta_encrypted_secrets".user_encrypted_secrets s
  WHERE
    s.name = get.secret_name
    AND s.user_id = get.user_id
  INTO v_secret;
  IF (NOT FOUND OR v_secret IS NULL) THEN
    RETURN get.default_value;
  END IF;
  
  IF (v_secret.enc = 'crypt') THEN
    RETURN convert_from(v_secret.value, 'SQL_ASCII');
  ELSIF (v_secret.enc = 'pgp') THEN
    RETURN convert_from(decode(pgp_sym_decrypt(v_secret.value, v_secret.user_id::text), 'hex'), 'SQL_ASCII');
  END IF;
  RETURN convert_from(v_secret.value, 'SQL_ASCII');
END
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION meta_encrypted_secrets.verify ( user_id uuid, secret_name text, secret_value text ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_secret_text text;
  v_secret "meta_encrypted_secrets".user_encrypted_secrets;
BEGIN
  SELECT
    *
  FROM
    "meta_encrypted_secrets".get (verify.user_id, verify.secret_name)
  INTO v_secret_text;
  SELECT
    *
  FROM
    "meta_encrypted_secrets".user_encrypted_secrets s
  WHERE
    s.name = verify.secret_name
    AND s.user_id = verify.user_id INTO v_secret;
  IF (v_secret.enc = 'crypt') THEN
    RETURN v_secret_text = crypt(verify.secret_value::bytea::text, v_secret_text);
  ELSIF (v_secret.enc = 'pgp') THEN
    RETURN verify.secret_value = v_secret_text;
  END IF;
  RETURN verify.secret_value = v_secret_text;
END
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION meta_encrypted_secrets.verify TO authenticated;

CREATE FUNCTION meta_encrypted_secrets.set ( v_user_id uuid, secret_name text, secret_value text, field_encoding text DEFAULT 'pgp' ) RETURNS boolean AS $EOFCODE$
BEGIN
  INSERT INTO "meta_encrypted_secrets".user_encrypted_secrets (user_id, name, value, enc)
    VALUES (v_user_id, set.secret_name, set.secret_value::bytea, set.field_encoding)
    ON CONFLICT (user_id, name)
    DO
    UPDATE
    SET
      value = set.secret_value::bytea,
      enc = EXCLUDED.enc;
  RETURN TRUE;
END
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION meta_encrypted_secrets.set TO authenticated;

CREATE FUNCTION meta_encrypted_secrets.del ( user_id uuid, secret_name text ) RETURNS void AS $EOFCODE$
BEGIN
  DELETE FROM "meta_encrypted_secrets".user_encrypted_secrets s
  WHERE s.user_id = del.user_id
    AND s.name = del.secret_name;
END
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION meta_encrypted_secrets.del ( user_id uuid, secret_names text[] ) RETURNS void AS $EOFCODE$
BEGIN
  DELETE FROM "meta_encrypted_secrets".user_encrypted_secrets s
  WHERE s.user_id = del.user_id
    AND s.name = ANY(del.secret_names);
END
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION meta_encrypted_secrets.del ( uuid,text ) TO authenticated;

GRANT EXECUTE ON FUNCTION meta_encrypted_secrets.del ( uuid,text[] ) TO authenticated;

CREATE FUNCTION meta_private.immutable_field_tg (  ) RETURNS trigger AS $EOFCODE$
BEGIN
  IF TG_NARGS > 0 THEN
    RAISE EXCEPTION 'IMMUTABLE_PROPERTY %', TG_ARGV[0];
  END IF;
  RAISE EXCEPTION 'IMMUTABLE_PROPERTY';
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION meta_private.authenticate ( token_str text ) RETURNS SETOF meta_private.api_tokens AS $EOFCODE$
SELECT
    tkn.*
FROM
    "meta_private".api_tokens AS tkn
WHERE
    tkn.access_token = authenticate.token_str
    AND EXTRACT(EPOCH FROM (tkn.access_token_expires_at-NOW())) > 0;
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE FUNCTION meta_public.get_current_user_id (  ) RETURNS uuid AS $EOFCODE$
DECLARE
  v_identifier_id uuid;
BEGIN
  IF current_setting('jwt.claims.user_id', TRUE)
    IS NOT NULL THEN
    BEGIN
      v_identifier_id = current_setting('jwt.claims.user_id', TRUE)::uuid;
    EXCEPTION
      WHEN OTHERS THEN
      RAISE NOTICE 'Invalid UUID value';
    RETURN NULL;
    END;
    RETURN v_identifier_id;
  ELSE
    RETURN NULL;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION meta_public.get_current_user_id TO authenticated;

CREATE FUNCTION meta_public.get_current_group_ids (  ) RETURNS uuid[] AS $EOFCODE$
DECLARE
  v_identifier_ids uuid[];
BEGIN
  IF current_setting('jwt.claims.group_ids', TRUE)
    IS NOT NULL THEN
    BEGIN
      v_identifier_ids = current_setting('jwt.claims.group_ids', TRUE)::uuid[];
    EXCEPTION
      WHEN OTHERS THEN
      RAISE NOTICE 'Invalid UUID value';
    RETURN ARRAY[]::uuid[];
    END;
    RETURN v_identifier_ids;
  ELSE
    RETURN ARRAY[]::uuid[];
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION meta_public.get_current_group_ids TO authenticated;

CREATE FUNCTION meta_public.get_current_user (  ) RETURNS meta_public.users AS $EOFCODE$
DECLARE
  v_user "meta_public".users;
BEGIN
  IF "meta_public".get_current_user_id() IS NOT NULL THEN
     SELECT * FROM "meta_public".users WHERE id = "meta_public".get_current_user_id() INTO v_user;
     RETURN v_user;
  ELSE
     RETURN NULL;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION meta_public.get_current_user TO authenticated;

CREATE FUNCTION meta_private.tg_peoplestamps (  ) RETURNS trigger AS $EOFCODE$
BEGIN
    IF TG_OP = 'INSERT' THEN
      NEW.updated_by = "meta_public".get_current_user_id();
      NEW.created_by = "meta_public".get_current_user_id();
    ELSIF TG_OP = 'UPDATE' THEN
      NEW.updated_by = OLD.updated_by;
      NEW.created_by = "meta_public".get_current_user_id();
    END IF;
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql;

CREATE FUNCTION meta_private.tg_timestamps (  ) RETURNS trigger AS $EOFCODE$
BEGIN
    IF TG_OP = 'INSERT' THEN
      NEW.created_at = NOW();
      NEW.updated_at = NOW();
    ELSIF TG_OP = 'UPDATE' THEN
      NEW.created_at = OLD.created_at;
      NEW.updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql;

ALTER TABLE meta_public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_insert_on_users ON meta_public.users FOR INSERT TO authenticated WITH CHECK ( id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_users ON meta_public.users FOR UPDATE TO authenticated USING ( id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_users ON meta_public.users FOR DELETE TO authenticated USING ( id = meta_public.get_current_user_id() );

GRANT INSERT ON TABLE meta_public.users TO authenticated;

GRANT UPDATE ON TABLE meta_public.users TO authenticated;

GRANT DELETE ON TABLE meta_public.users TO authenticated;

CREATE POLICY authenticated_can_select_on_users ON meta_public.users FOR SELECT TO authenticated USING ( TRUE );

GRANT SELECT ON TABLE meta_public.users TO authenticated;

ALTER TABLE meta_encrypted_secrets.user_encrypted_secrets ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_user_encrypted_secrets ON meta_encrypted_secrets.user_encrypted_secrets FOR SELECT TO authenticated USING ( user_id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_user_encrypted_secrets ON meta_encrypted_secrets.user_encrypted_secrets FOR INSERT TO authenticated WITH CHECK ( user_id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_user_encrypted_secrets ON meta_encrypted_secrets.user_encrypted_secrets FOR UPDATE TO authenticated USING ( user_id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_user_encrypted_secrets ON meta_encrypted_secrets.user_encrypted_secrets FOR DELETE TO authenticated USING ( user_id = meta_public.get_current_user_id() );

GRANT SELECT ON TABLE meta_encrypted_secrets.user_encrypted_secrets TO authenticated;

GRANT INSERT ON TABLE meta_encrypted_secrets.user_encrypted_secrets TO authenticated;

GRANT UPDATE ON TABLE meta_encrypted_secrets.user_encrypted_secrets TO authenticated;

GRANT DELETE ON TABLE meta_encrypted_secrets.user_encrypted_secrets TO authenticated;

ALTER TABLE meta_simple_secrets.user_secrets ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_user_secrets ON meta_simple_secrets.user_secrets FOR SELECT TO authenticated USING ( user_id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_user_secrets ON meta_simple_secrets.user_secrets FOR INSERT TO authenticated WITH CHECK ( user_id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_user_secrets ON meta_simple_secrets.user_secrets FOR UPDATE TO authenticated USING ( user_id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_user_secrets ON meta_simple_secrets.user_secrets FOR DELETE TO authenticated USING ( user_id = meta_public.get_current_user_id() );

GRANT SELECT ON TABLE meta_simple_secrets.user_secrets TO authenticated;

GRANT INSERT ON TABLE meta_simple_secrets.user_secrets TO authenticated;

GRANT UPDATE ON TABLE meta_simple_secrets.user_secrets TO authenticated;

GRANT DELETE ON TABLE meta_simple_secrets.user_secrets TO authenticated;

ALTER TABLE meta_private.api_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_api_tokens ON meta_private.api_tokens FOR SELECT TO authenticated USING ( user_id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_api_tokens ON meta_private.api_tokens FOR INSERT TO authenticated WITH CHECK ( user_id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_api_tokens ON meta_private.api_tokens FOR UPDATE TO authenticated USING ( user_id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_api_tokens ON meta_private.api_tokens FOR DELETE TO authenticated USING ( user_id = meta_public.get_current_user_id() );

GRANT SELECT ON TABLE meta_private.api_tokens TO authenticated;

GRANT INSERT ON TABLE meta_private.api_tokens TO authenticated;

GRANT UPDATE ON TABLE meta_private.api_tokens TO authenticated;

GRANT DELETE ON TABLE meta_private.api_tokens TO authenticated;

CREATE TABLE meta_public.emails (
  
);

ALTER TABLE meta_public.emails DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.emails ADD COLUMN  id uuid;

ALTER TABLE meta_public.emails ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.emails ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.emails ADD COLUMN  user_id uuid;

ALTER TABLE meta_public.emails ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE meta_public.emails ADD COLUMN  email email;

ALTER TABLE meta_public.emails ALTER COLUMN email SET NOT NULL;

ALTER TABLE meta_public.emails ADD COLUMN  is_verified boolean;

ALTER TABLE meta_public.emails ALTER COLUMN is_verified SET NOT NULL;

ALTER TABLE meta_public.emails ALTER COLUMN is_verified SET DEFAULT FALSE;

ALTER TABLE meta_public.emails ADD CONSTRAINT emails_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.emails ADD CONSTRAINT emails_email_key UNIQUE ( email );

ALTER TABLE meta_public.emails ADD CONSTRAINT emails_user_id_key UNIQUE ( user_id );

ALTER TABLE meta_public.emails ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_emails ON meta_public.emails FOR SELECT TO authenticated USING ( user_id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_insert_on_emails ON meta_public.emails FOR INSERT TO authenticated WITH CHECK ( user_id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_update_on_emails ON meta_public.emails FOR UPDATE TO authenticated USING ( user_id = meta_public.get_current_user_id() );

CREATE POLICY authenticated_can_delete_on_emails ON meta_public.emails FOR DELETE TO authenticated USING ( user_id = meta_public.get_current_user_id() );

GRANT SELECT ON TABLE meta_public.emails TO authenticated;

GRANT INSERT ON TABLE meta_public.emails TO authenticated;

GRANT UPDATE ON TABLE meta_public.emails TO authenticated;

GRANT DELETE ON TABLE meta_public.emails TO authenticated;

ALTER TABLE meta_public.emails ADD CONSTRAINT emails_user_id_fkey FOREIGN KEY ( user_id ) REFERENCES meta_public.users ( id );

COMMENT ON CONSTRAINT emails_user_id_fkey ON meta_public.emails IS NULL;

CREATE INDEX emails_user_id_idx ON meta_public.emails ( user_id );

CREATE TRIGGER emails_insert_job_tg 
 AFTER INSERT ON meta_public.emails 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_jobs. tg_add_job_with_row ( 'new-user-email' );

CREATE FUNCTION meta_public.login ( email text, password text ) RETURNS meta_private.api_tokens AS $EOFCODE$
DECLARE
  v_token "meta_private".api_tokens;
  v_email "meta_public".emails;
  v_sign_in_attempt_window_duration interval = interval '6 hours';
  v_sign_in_max_attempts int = 10;
  first_failed_password_attempt timestamptz;
  password_attempts int;
BEGIN
  SELECT
    user_emails_alias.*
  FROM
    "meta_public".emails AS user_emails_alias
  WHERE
    user_emails_alias.email = login.email::email INTO v_email;
  
  IF (NOT FOUND) THEN
    RETURN NULL;
  END IF;
  SELECT value FROM "meta_simple_secrets".user_secrets t 
    WHERE t.user_id = v_email.user_id
    AND t.name = 'first_failed_password_attempt'
  INTO first_failed_password_attempt;
  
  SELECT value FROM "meta_simple_secrets".user_secrets t 
    WHERE t.user_id = v_email.user_id
    AND t.name = 'password_attempts'
  INTO password_attempts;
  IF (
    first_failed_password_attempt IS NOT NULL
      AND
    first_failed_password_attempt > NOW() - v_sign_in_attempt_window_duration
      AND
    password_attempts >= v_sign_in_max_attempts
  ) THEN
    RAISE EXCEPTION 'ACCOUNT_LOCKED_EXCEED_ATTEMPTS';
  END IF;
  IF ("meta_encrypted_secrets".verify(v_email.user_id, 'password_hash', PASSWORD)) THEN
    DELETE FROM "meta_simple_secrets".user_secrets s 
      WHERE
      s.user_id = v_email.user_id
      AND s.name IN ('password_attempts', 'first_failed_password_attempt');
    INSERT INTO "meta_private".api_tokens (user_id)
      VALUES (v_email.user_id)
    RETURNING
      * INTO v_token;
    RETURN v_token;
  ELSE
    IF (password_attempts IS NULL) THEN
      password_attempts = 0;
    END IF;
    IF (
      first_failed_password_attempt IS NULL
        OR
      first_failed_password_attempt < NOW() - v_sign_in_attempt_window_duration
    ) THEN
      password_attempts = 1;
      first_failed_password_attempt = NOW();
    ELSE 
      password_attempts = password_attempts + 1;
    END IF;
    INSERT INTO "meta_simple_secrets".user_secrets 
      (user_id, name, value)
    VALUES
      (v_email.user_id, 'password_attempts', password_attempts),
      (v_email.user_id, 'first_failed_password_attempt', first_failed_password_attempt)
    ON CONFLICT (user_id, name)
    DO UPDATE 
    SET value = EXCLUDED.value;
    RETURN NULL;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql STRICT SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION meta_public.login TO anonymous;

CREATE FUNCTION meta_public.register ( email text, password text ) RETURNS meta_private.api_tokens AS $EOFCODE$
DECLARE
  v_user "meta_public".users;
  v_email "meta_public".emails;
  v_token "meta_private".api_tokens;
BEGIN
  IF (password IS NULL) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  password = trim(password);
  IF (character_length(password) <= 7 OR character_length(password) >= 64) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  SELECT * FROM "meta_public".emails t
    WHERE trim(register.email)::email = t.email
  INTO v_email;
  IF (NOT FOUND) THEN
    INSERT INTO "meta_public".users
      DEFAULT VALUES
    RETURNING
      * INTO v_user;
    INSERT INTO "meta_public".emails (user_id, email)
      VALUES (v_user.id, trim(register.email))
    RETURNING
      * INTO v_email;
    INSERT INTO "meta_private".api_tokens (user_id)
      VALUES (v_user.id)
    RETURNING
      * INTO v_token;
    PERFORM "meta_encrypted_secrets".set
      (v_user.id, 'password_hash', trim(password), 'crypt');
    RETURN v_token;
  END IF;
  RAISE EXCEPTION 'ACCOUNT_EXISTS';
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION meta_public.register TO anonymous;

CREATE FUNCTION meta_public.set_password ( new_password text ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_user "meta_public".users;
  v_user_secret "meta_simple_secrets".user_secrets;
BEGIN
  IF (new_password IS NULL OR character_length(new_password) <= 7) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  SELECT
    u.* INTO v_user
  FROM
    "meta_public".users AS u
  WHERE
    id = "meta_public".get_current_user_id ();
  IF (NOT FOUND) THEN
    RETURN FALSE;
  END IF;
  PERFORM "meta_encrypted_secrets".set
    (v_user.id, 'password_hash', new_password, 'crypt');
  DELETE FROM "meta_simple_secrets".user_secrets s 
    WHERE
    s.user_id = v_user.id
    AND s.name IN
      (
        'password_attempts',
        'first_failed_password_attempt',
        'reset_password_token_generated',
        'reset_password_attempts',
        'first_failed_reset_password_attempt'
      );
  DELETE FROM "meta_encrypted_secrets".user_encrypted_secrets s 
    WHERE
    s.user_id = v_user.id
    AND s.name IN
      (
        'reset_password_token'
      );
      
  RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION meta_public.set_password TO authenticated;

CREATE FUNCTION meta_public.reset_password ( role_id uuid, reset_token text, new_password text ) RETURNS boolean AS $EOFCODE$
DECLARE
    v_user "meta_public".users;
    
    v_reset_max_interval interval = interval '3 days';
    v_reset_max_attempts int = 10;
    reset_password_attempts int;
    first_failed_reset_password_attempt timestamptz;
BEGIN
    IF (role_id IS NULL OR reset_token IS NULL OR new_password IS NULL) THEN
        RAISE EXCEPTION 'NULL_VALUES_DISALLOWED';
    END IF;
    SELECT
        u.* INTO v_user
    FROM
        "meta_public".users as u
    WHERE
        id = role_id;
    IF (NOT FOUND) THEN
      RETURN NULL;
    END IF;
    reset_password_attempts = "meta_simple_secrets".get(v_user.id, 'reset_password_attempts', '0');
    first_failed_reset_password_attempt = "meta_simple_secrets".get(v_user.id, 'first_failed_reset_password_attempt');
    IF (first_failed_reset_password_attempt IS NOT NULL
      AND NOW() < first_failed_reset_password_attempt + v_reset_max_interval
      AND reset_password_attempts >= v_reset_max_attempts) THEN
        RAISE
        EXCEPTION 'PASSWORD_RESET_LOCKED_EXCEED_ATTEMPTS';
    END IF;
    IF ("meta_encrypted_secrets".verify(v_user.id, 'reset_password_token', reset_token)) THEN
        PERFORM "meta_encrypted_secrets".set
            (v_user.id, 'password_hash', new_password, 'crypt');
        PERFORM "meta_simple_secrets".del(
            v_user.id,
            ARRAY[
                'password_attempts',
                'first_failed_password_attempt',
                'reset_password_token_generated',
                'reset_password_attempts',
                'first_failed_reset_password_attempt'                
            ]
        );
        DELETE FROM "meta_encrypted_secrets".user_encrypted_secrets s 
            WHERE
            s.user_id = v_user.id
            AND s.name IN
            (
                'reset_password_token'
            );
        RETURN TRUE;
    ELSE
        IF (
            first_failed_reset_password_attempt IS NULL OR
            first_failed_reset_password_attempt + v_reset_max_interval < NOW() 
        ) THEN
            reset_password_attempts = 1;
            first_failed_reset_password_attempt = NOW();
        ELSE 
            reset_password_attempts = reset_password_attempts + 1;
        END IF;
        PERFORM "meta_simple_secrets".set(v_user.id, 'reset_password_attempts', reset_password_attempts);
        PERFORM "meta_simple_secrets".set(v_user.id, 'first_failed_reset_password_attempt', first_failed_reset_password_attempt);
    END IF;
    RETURN FALSE;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION meta_public.reset_password TO anonymous;

REVOKE EXECUTE ON FUNCTION meta_public.reset_password FROM authenticated;

CREATE FUNCTION meta_public.forgot_password ( email email ) RETURNS void AS $EOFCODE$
DECLARE
    v_email "meta_public".emails;
    v_user_id uuid;
    v_reset_token text;
    v_reset_min_duration_between_emails interval = interval '3 minutes';
    
    v_reset_max_duration interval = interval '3 days';
    password_reset_email_sent_at timestamptz;
BEGIN
    SELECT * FROM "meta_public".emails e
        WHERE e.email = forgot_password.email::email
    INTO v_email;
    IF (NOT FOUND) THEN
        RETURN;
    END IF;
    v_user_id = v_email.user_id;
    password_reset_email_sent_at = "meta_simple_secrets".get(v_user_id, 'password_reset_email_sent_at');
    IF (
        password_reset_email_sent_at IS NOT NULL AND
        NOW() < password_reset_email_sent_at + v_reset_min_duration_between_emails
    ) THEN 
        RETURN;
    END IF;
    v_reset_token = encode(gen_random_bytes(7), 'hex');
    PERFORM "meta_encrypted_secrets".set
        (v_user_id, 'reset_password_token', v_reset_token, 'crypt');
    PERFORM "meta_simple_secrets".set(v_user_id, 'password_reset_email_sent_at', (NOW())::text);
    PERFORM
        "meta_jobs".add_job ('user__forgot_password',
            json_build_object('user_id', v_user_id, 'email', v_email.email::text, 'token', v_reset_token));
    RETURN;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION meta_public.forgot_password TO anonymous;

CREATE FUNCTION meta_public.send_verification_email ( email email ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_email "meta_public".emails;
  v_user_id uuid;
  v_verification_token text;
  v_verification_min_duration_between_emails interval = interval '3 minutes';
  v_verification_min_duration_between_new_tokens interval = interval '10 minutes';
  verification_token_name text;
  verification_email_sent_at timestamptz;
BEGIN
  SELECT * FROM "meta_public".emails e
    WHERE e.email = send_verification_email.email
  INTO v_email;
  IF (NOT FOUND) THEN 
    RETURN FALSE;
  END IF;
  verification_token_name = v_email.email::text || '_verification_token';
  IF ( v_email.is_verified IS TRUE ) THEN
    PERFORM "meta_simple_secrets".del(v_email.user_id, ARRAY[
        'verification_email_sent_at',
        'verification_email_attempts',
        'first_failed_verification_email_attempt'
    ]);
    PERFORM "meta_encrypted_secrets".del(v_email.user_id, ARRAY[
        verification_token_name
    ]);
    RETURN FALSE;
  END IF;
  v_user_id = v_email.user_id;
  verification_email_sent_at = "meta_simple_secrets".get(v_user_id, 'verification_email_sent_at');
    IF (
      verification_email_sent_at IS NOT NULL AND
      NOW() < verification_email_sent_at + v_verification_min_duration_between_emails
    ) THEN 
        RETURN NULL;
    END IF;
  
  IF (
    verification_email_sent_at IS NOT NULL AND
    NOW() < verification_email_sent_at + v_verification_min_duration_between_new_tokens 
  ) THEN 
    v_verification_token = "meta_encrypted_secrets".get
        (v_user_id, verification_token_name, encode(gen_random_bytes(10), 'hex'));
  ELSE
    v_verification_token = encode(gen_random_bytes(10), 'hex');
  END IF;
  verification_email_sent_at = NOW();
  PERFORM "meta_simple_secrets".set
    (v_user_id, 'verification_email_sent_at', verification_email_sent_at);
  PERFORM "meta_encrypted_secrets".set
    (v_user_id, verification_token_name, v_verification_token, 'pgp');
  PERFORM
      "meta_jobs".add_job ('user_emails__send_verification',
        json_build_object(
          'email_id', v_email.id,
          'email', email,
          'verification_token', v_verification_token
        )
      );
  RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION meta_public.send_verification_email TO authenticated, anonymous;

CREATE FUNCTION meta_public.verify_email ( email_id uuid, token text ) RETURNS boolean AS $EOFCODE$
DECLARE
  v_email "meta_public".emails;
  v_user_id uuid;
  
  v_verification_expires_interval interval = interval '3 days';
  verification_token_name text;
  verification_email_attempts int;
  verification_email_sent_at timestamptz;
  first_failed_verification_email_attempt timestamptz;
BEGIN
  
  SELECT * FROM "meta_public".emails e
     WHERE e.id = verify_email.email_id
     AND e.is_verified = FALSE
  INTO v_email;
  IF ( NOT FOUND ) THEN
    RETURN FALSE;
  END IF;
  v_user_id = v_email.user_id;
  verification_email_sent_at = "meta_simple_secrets".get(v_user_id, 'verification_email_sent_at');
  IF (verification_email_sent_at IS NOT NULL AND 
    verification_email_sent_at + v_verification_expires_interval < NOW() 
  ) THEN 
    
    PERFORM "meta_simple_secrets".del(v_user_id, ARRAY[
        'verification_email_sent_at',
        'verification_email_attempts',
        'first_failed_verification_email_attempt'
    ]);
    PERFORM "meta_encrypted_secrets".del(v_user_id, verification_token_name);
    RETURN FALSE;
  END IF;
  verification_token_name = v_email.email::text || '_verification_token';
  IF ("meta_encrypted_secrets".verify (v_user_id, verification_token_name, verify_email.token) ) THEN
    UPDATE "meta_public".emails e
        SET is_verified = TRUE
    WHERE e.id = verify_email.email_id;
    PERFORM "meta_simple_secrets".del(v_user_id, ARRAY[
        'verification_email_sent_at',
        'verification_email_attempts',
        'first_failed_verification_email_attempt'
    ]);
    PERFORM "meta_encrypted_secrets".del(v_user_id, verification_token_name);
    RETURN TRUE;
  ELSE
    IF (
        first_failed_verification_email_attempt IS NULL OR
        first_failed_verification_email_attempt + v_verification_expires_interval < NOW()
    ) THEN
        verification_email_attempts = 1;
        first_failed_verification_email_attempt = NOW();
    ELSE 
        verification_email_attempts = verification_email_attempts + 1;
    END IF;
    PERFORM "meta_simple_secrets".set(v_user_id, 'verification_email_attempts', verification_email_attempts);
    PERFORM "meta_simple_secrets".set(v_user_id, 'first_failed_verification_email_attempt', first_failed_verification_email_attempt);
    RETURN FALSE;
  END IF;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION meta_public.verify_email TO anonymous, authenticated;

CREATE TABLE meta_public.addresses (
  
);

ALTER TABLE meta_public.addresses DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.addresses ADD COLUMN  id uuid;

ALTER TABLE meta_public.addresses ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.addresses ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.addresses ADD CONSTRAINT addresses_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.addresses ADD COLUMN  address_line_1 text;

ALTER TABLE meta_public.addresses ADD CONSTRAINT addresses_address_line_1_chk CHECK ( character_length(address_line_1) <= 120 );

ALTER TABLE meta_public.addresses ADD COLUMN  address_line_2 text;

ALTER TABLE meta_public.addresses ADD CONSTRAINT addresses_address_line_2_chk CHECK ( character_length(address_line_2) <= 120 );

ALTER TABLE meta_public.addresses ADD COLUMN  address_line_3 text;

ALTER TABLE meta_public.addresses ADD CONSTRAINT addresses_address_line_3_chk CHECK ( character_length(address_line_3) <= 120 );

ALTER TABLE meta_public.addresses ADD COLUMN  city text;

ALTER TABLE meta_public.addresses ADD CONSTRAINT addresses_city_chk CHECK ( character_length(city) <= 120 );

ALTER TABLE meta_public.addresses ADD COLUMN  state text;

ALTER TABLE meta_public.addresses ADD CONSTRAINT addresses_state_chk CHECK ( character_length(state) <= 120 );

ALTER TABLE meta_public.addresses ADD COLUMN  county_province text;

ALTER TABLE meta_public.addresses ADD CONSTRAINT addresses_county_province_chk CHECK ( character_length(county_province) <= 120 );

ALTER TABLE meta_public.addresses ADD COLUMN  postcode text;

ALTER TABLE meta_public.addresses ADD CONSTRAINT addresses_postcode_chk CHECK ( character_length(postcode) <= 24 );

ALTER TABLE meta_public.addresses ADD COLUMN  other text;

ALTER TABLE meta_public.addresses ADD CONSTRAINT addresses_other_chk CHECK ( character_length(other) <= 120 );

ALTER TABLE meta_public.addresses ADD COLUMN  created_by uuid;

ALTER TABLE meta_public.addresses ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON meta_public.addresses 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_peoplestamps (  );

ALTER TABLE meta_public.addresses ADD COLUMN  created_at timestamptz;

ALTER TABLE meta_public.addresses ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE meta_public.addresses ADD COLUMN  updated_at timestamptz;

ALTER TABLE meta_public.addresses ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON meta_public.addresses 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_timestamps (  );

ALTER TABLE meta_public.addresses ADD COLUMN  owner_id uuid;

ALTER TABLE meta_public.addresses ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE meta_public.addresses ADD CONSTRAINT addresses_owner_id_fkey FOREIGN KEY ( owner_id ) REFERENCES meta_public.users ( id );

COMMENT ON CONSTRAINT addresses_owner_id_fkey ON meta_public.addresses IS E'@omit manyToMany';

CREATE INDEX addresses_owner_id_idx ON meta_public.addresses ( owner_id );

ALTER TABLE meta_public.addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_addresses ON meta_public.addresses FOR SELECT TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_insert_on_addresses ON meta_public.addresses FOR INSERT TO authenticated WITH CHECK ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_update_on_addresses ON meta_public.addresses FOR UPDATE TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_delete_on_addresses ON meta_public.addresses FOR DELETE TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

GRANT SELECT ON TABLE meta_public.addresses TO authenticated;

GRANT INSERT ON TABLE meta_public.addresses TO authenticated;

GRANT UPDATE ON TABLE meta_public.addresses TO authenticated;

GRANT DELETE ON TABLE meta_public.addresses TO authenticated;

CREATE TABLE meta_public.phone_numbers (
  
);

ALTER TABLE meta_public.phone_numbers DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.phone_numbers ADD COLUMN  id uuid;

ALTER TABLE meta_public.phone_numbers ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.phone_numbers ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.phone_numbers ADD CONSTRAINT phone_numbers_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.phone_numbers ADD COLUMN  country_code int;

ALTER TABLE meta_public.phone_numbers ALTER COLUMN country_code SET NOT NULL;

ALTER TABLE meta_public.phone_numbers ADD COLUMN  number int;

ALTER TABLE meta_public.phone_numbers ALTER COLUMN number SET NOT NULL;

ALTER TABLE meta_public.phone_numbers ADD COLUMN  created_by uuid;

ALTER TABLE meta_public.phone_numbers ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON meta_public.phone_numbers 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_peoplestamps (  );

ALTER TABLE meta_public.phone_numbers ADD COLUMN  created_at timestamptz;

ALTER TABLE meta_public.phone_numbers ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE meta_public.phone_numbers ADD COLUMN  updated_at timestamptz;

ALTER TABLE meta_public.phone_numbers ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON meta_public.phone_numbers 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_timestamps (  );

ALTER TABLE meta_public.phone_numbers ADD COLUMN  owner_id uuid;

ALTER TABLE meta_public.phone_numbers ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE meta_public.phone_numbers ADD CONSTRAINT phone_numbers_owner_id_fkey FOREIGN KEY ( owner_id ) REFERENCES meta_public.users ( id );

COMMENT ON CONSTRAINT phone_numbers_owner_id_fkey ON meta_public.phone_numbers IS E'@omit manyToMany';

CREATE INDEX phone_numbers_owner_id_idx ON meta_public.phone_numbers ( owner_id );

ALTER TABLE meta_public.phone_numbers ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_phone_numbers ON meta_public.phone_numbers FOR SELECT TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_insert_on_phone_numbers ON meta_public.phone_numbers FOR INSERT TO authenticated WITH CHECK ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_update_on_phone_numbers ON meta_public.phone_numbers FOR UPDATE TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_delete_on_phone_numbers ON meta_public.phone_numbers FOR DELETE TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

GRANT SELECT ON TABLE meta_public.phone_numbers TO authenticated;

GRANT INSERT ON TABLE meta_public.phone_numbers TO authenticated;

GRANT UPDATE ON TABLE meta_public.phone_numbers TO authenticated;

GRANT DELETE ON TABLE meta_public.phone_numbers TO authenticated;

CREATE TABLE meta_public.organization_settings (
  
);

ALTER TABLE meta_public.organization_settings DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.organization_settings ADD COLUMN  id uuid;

ALTER TABLE meta_public.organization_settings ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.organization_settings ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.organization_settings ADD CONSTRAINT organization_settings_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.organization_settings ADD COLUMN  legal_name text;

ALTER TABLE meta_public.organization_settings ADD CONSTRAINT organization_settings_legal_name_chk CHECK ( character_length(legal_name) <= 255 );

ALTER TABLE meta_public.organization_settings ADD COLUMN  dba text;

ALTER TABLE meta_public.organization_settings ADD CONSTRAINT organization_settings_dba_chk CHECK ( character_length(dba) <= 255 );

ALTER TABLE meta_public.organization_settings ADD COLUMN  industry text;

ALTER TABLE meta_public.organization_settings ADD CONSTRAINT organization_settings_industry_chk CHECK ( character_length(industry) <= 255 );

ALTER TABLE meta_public.organization_settings ADD COLUMN  description text;

ALTER TABLE meta_public.organization_settings ADD CONSTRAINT organization_settings_description_chk CHECK ( character_length(description) <= 1024 );

ALTER TABLE meta_public.organization_settings ADD COLUMN  website url;

ALTER TABLE meta_public.organization_settings ADD COLUMN  business_type text;

ALTER TABLE meta_public.organization_settings ADD COLUMN  created_by uuid;

ALTER TABLE meta_public.organization_settings ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON meta_public.organization_settings 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_peoplestamps (  );

ALTER TABLE meta_public.organization_settings ADD COLUMN  created_at timestamptz;

ALTER TABLE meta_public.organization_settings ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE meta_public.organization_settings ADD COLUMN  updated_at timestamptz;

ALTER TABLE meta_public.organization_settings ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON meta_public.organization_settings 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_timestamps (  );

ALTER TABLE meta_public.organization_settings ADD COLUMN  organization_id uuid;

ALTER TABLE meta_public.organization_settings ALTER COLUMN organization_id SET NOT NULL;

ALTER TABLE meta_public.organization_settings ADD CONSTRAINT organization_settings_organization_id_fkey FOREIGN KEY ( organization_id ) REFERENCES meta_public.users ( id );

COMMENT ON CONSTRAINT organization_settings_organization_id_fkey ON meta_public.organization_settings IS E'@omit manyToMany';

CREATE INDEX organization_settings_organization_id_idx ON meta_public.organization_settings ( organization_id );

ALTER TABLE meta_public.organization_settings ADD COLUMN  address_id uuid;

ALTER TABLE meta_public.organization_settings ADD CONSTRAINT organization_settings_address_id_fkey FOREIGN KEY ( address_id ) REFERENCES meta_public.addresses ( id );

COMMENT ON CONSTRAINT organization_settings_address_id_fkey ON meta_public.organization_settings IS E'@omit manyToMany';

CREATE INDEX organization_settings_address_id_idx ON meta_public.organization_settings ( address_id );

ALTER TABLE meta_public.organization_settings ADD COLUMN  phone_id uuid;

ALTER TABLE meta_public.organization_settings ADD CONSTRAINT organization_settings_phone_id_fkey FOREIGN KEY ( phone_id ) REFERENCES meta_public.phone_numbers ( id );

COMMENT ON CONSTRAINT organization_settings_phone_id_fkey ON meta_public.organization_settings IS E'@omit manyToMany';

CREATE INDEX organization_settings_phone_id_idx ON meta_public.organization_settings ( phone_id );

ALTER TABLE meta_public.organization_settings ADD CONSTRAINT organization_settings_organization_id_key UNIQUE ( organization_id );

COMMENT ON CONSTRAINT organization_settings_organization_id_key ON meta_public.organization_settings IS E'@omit';

ALTER TABLE meta_public.organization_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_organization_settings ON meta_public.organization_settings FOR SELECT TO authenticated USING ( organization_id = meta_public.get_current_user_id() OR organization_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_insert_on_organization_settings ON meta_public.organization_settings FOR INSERT TO authenticated WITH CHECK ( organization_id = meta_public.get_current_user_id() OR organization_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_update_on_organization_settings ON meta_public.organization_settings FOR UPDATE TO authenticated USING ( organization_id = meta_public.get_current_user_id() OR organization_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_delete_on_organization_settings ON meta_public.organization_settings FOR DELETE TO authenticated USING ( organization_id = meta_public.get_current_user_id() OR organization_id = ANY (meta_public.get_current_group_ids()) );

GRANT SELECT ON TABLE meta_public.organization_settings TO authenticated;

GRANT INSERT ON TABLE meta_public.organization_settings TO authenticated;

GRANT UPDATE ON TABLE meta_public.organization_settings TO authenticated;

GRANT DELETE ON TABLE meta_public.organization_settings TO authenticated;

CREATE TABLE meta_public.domains (
  
);

ALTER TABLE meta_public.domains DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.domains ADD COLUMN  id uuid;

ALTER TABLE meta_public.domains ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.domains ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.domains ADD CONSTRAINT domains_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.domains ADD COLUMN  subdomain hostname;

ALTER TABLE meta_public.domains ADD COLUMN  domain hostname;

ALTER TABLE meta_public.domains ADD COLUMN  created_by uuid;

ALTER TABLE meta_public.domains ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON meta_public.domains 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_peoplestamps (  );

ALTER TABLE meta_public.domains ADD COLUMN  created_at timestamptz;

ALTER TABLE meta_public.domains ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE meta_public.domains ADD COLUMN  updated_at timestamptz;

ALTER TABLE meta_public.domains ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON meta_public.domains 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_timestamps (  );

ALTER TABLE meta_public.domains ADD COLUMN  owner_id uuid;

ALTER TABLE meta_public.domains ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE meta_public.domains ADD CONSTRAINT domains_owner_id_fkey FOREIGN KEY ( owner_id ) REFERENCES meta_public.users ( id );

COMMENT ON CONSTRAINT domains_owner_id_fkey ON meta_public.domains IS E'@omit manyToMany';

CREATE INDEX domains_owner_id_idx ON meta_public.domains ( owner_id );

ALTER TABLE meta_public.domains ADD CONSTRAINT domains_subdomain_domain_key UNIQUE ( subdomain, domain );

COMMENT ON CONSTRAINT domains_subdomain_domain_key ON meta_public.domains IS NULL;

ALTER TABLE meta_public.domains ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_domains ON meta_public.domains FOR SELECT TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_insert_on_domains ON meta_public.domains FOR INSERT TO authenticated WITH CHECK ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_update_on_domains ON meta_public.domains FOR UPDATE TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_delete_on_domains ON meta_public.domains FOR DELETE TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

GRANT SELECT ON TABLE meta_public.domains TO authenticated;

GRANT INSERT ON TABLE meta_public.domains TO authenticated;

GRANT UPDATE ON TABLE meta_public.domains TO authenticated;

GRANT DELETE ON TABLE meta_public.domains TO authenticated;

CREATE TABLE meta_public.apis (
  
);

ALTER TABLE meta_public.apis DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.apis ADD COLUMN  id uuid;

ALTER TABLE meta_public.apis ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.apis ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.apis ADD CONSTRAINT apis_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.apis ADD COLUMN  schemas text[];

ALTER TABLE meta_public.apis ALTER COLUMN schemas SET NOT NULL;

ALTER TABLE meta_public.apis ADD COLUMN  dbname text;

ALTER TABLE meta_public.apis ALTER COLUMN dbname SET NOT NULL;

ALTER TABLE meta_public.apis ALTER COLUMN dbname SET DEFAULT current_database();

ALTER TABLE meta_public.apis ADD COLUMN  role_name text;

ALTER TABLE meta_public.apis ALTER COLUMN role_name SET NOT NULL;

ALTER TABLE meta_public.apis ALTER COLUMN role_name SET DEFAULT 'authenticated';

ALTER TABLE meta_public.apis ADD COLUMN  anon_role text;

ALTER TABLE meta_public.apis ALTER COLUMN anon_role SET NOT NULL;

ALTER TABLE meta_public.apis ALTER COLUMN anon_role SET DEFAULT 'anonymous';

ALTER TABLE meta_public.apis ADD COLUMN  created_by uuid;

ALTER TABLE meta_public.apis ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON meta_public.apis 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_peoplestamps (  );

ALTER TABLE meta_public.apis ADD COLUMN  created_at timestamptz;

ALTER TABLE meta_public.apis ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE meta_public.apis ADD COLUMN  updated_at timestamptz;

ALTER TABLE meta_public.apis ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON meta_public.apis 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_timestamps (  );

ALTER TABLE meta_public.apis ADD COLUMN  owner_id uuid;

ALTER TABLE meta_public.apis ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE meta_public.apis ADD CONSTRAINT apis_owner_id_fkey FOREIGN KEY ( owner_id ) REFERENCES meta_public.users ( id );

COMMENT ON CONSTRAINT apis_owner_id_fkey ON meta_public.apis IS E'@omit manyToMany';

CREATE INDEX apis_owner_id_idx ON meta_public.apis ( owner_id );

ALTER TABLE meta_public.apis ADD COLUMN  domain_id uuid;

ALTER TABLE meta_public.apis ALTER COLUMN domain_id SET NOT NULL;

ALTER TABLE meta_public.apis ADD CONSTRAINT apis_domain_id_fkey FOREIGN KEY ( domain_id ) REFERENCES meta_public.domains ( id );

COMMENT ON CONSTRAINT apis_domain_id_fkey ON meta_public.apis IS E'@omit manyToMany';

CREATE INDEX apis_domain_id_idx ON meta_public.apis ( domain_id );

ALTER TABLE meta_public.apis ADD CONSTRAINT apis_domain_id_key UNIQUE ( domain_id );

COMMENT ON CONSTRAINT apis_domain_id_key ON meta_public.apis IS NULL;

ALTER TABLE meta_public.apis ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_apis ON meta_public.apis FOR SELECT TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_insert_on_apis ON meta_public.apis FOR INSERT TO authenticated WITH CHECK ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_update_on_apis ON meta_public.apis FOR UPDATE TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_delete_on_apis ON meta_public.apis FOR DELETE TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

GRANT SELECT ON TABLE meta_public.apis TO authenticated;

GRANT INSERT ON TABLE meta_public.apis TO authenticated;

GRANT UPDATE ON TABLE meta_public.apis TO authenticated;

GRANT DELETE ON TABLE meta_public.apis TO authenticated;

CREATE TABLE meta_public.sites (
  
);

ALTER TABLE meta_public.sites DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.sites ADD COLUMN  id uuid;

ALTER TABLE meta_public.sites ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.sites ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.sites ADD CONSTRAINT sites_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.sites ADD COLUMN  title text;

ALTER TABLE meta_public.sites ADD CONSTRAINT sites_title_chk CHECK ( character_length(title) <= 120 );

ALTER TABLE meta_public.sites ADD COLUMN  description text;

ALTER TABLE meta_public.sites ADD CONSTRAINT sites_description_chk CHECK ( character_length(description) <= 120 );

ALTER TABLE meta_public.sites ADD COLUMN  og_image image;

ALTER TABLE meta_public.sites ADD COLUMN  favicon upload;

ALTER TABLE meta_public.sites ADD COLUMN  logo image;

ALTER TABLE meta_public.sites ADD COLUMN  dbname text;

ALTER TABLE meta_public.sites ALTER COLUMN dbname SET NOT NULL;

ALTER TABLE meta_public.sites ALTER COLUMN dbname SET DEFAULT current_database();

ALTER TABLE meta_public.sites ADD COLUMN  created_by uuid;

ALTER TABLE meta_public.sites ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON meta_public.sites 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_peoplestamps (  );

ALTER TABLE meta_public.sites ADD COLUMN  created_at timestamptz;

ALTER TABLE meta_public.sites ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE meta_public.sites ADD COLUMN  updated_at timestamptz;

ALTER TABLE meta_public.sites ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON meta_public.sites 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_timestamps (  );

ALTER TABLE meta_public.sites ADD COLUMN  domain_id uuid;

ALTER TABLE meta_public.sites ALTER COLUMN domain_id SET NOT NULL;

ALTER TABLE meta_public.sites ADD CONSTRAINT sites_domain_id_fkey FOREIGN KEY ( domain_id ) REFERENCES meta_public.domains ( id );

COMMENT ON CONSTRAINT sites_domain_id_fkey ON meta_public.sites IS E'@omit manyToMany';

CREATE INDEX sites_domain_id_idx ON meta_public.sites ( domain_id );

ALTER TABLE meta_public.sites ADD CONSTRAINT sites_domain_id_key UNIQUE ( domain_id );

COMMENT ON CONSTRAINT sites_domain_id_key ON meta_public.sites IS NULL;

ALTER TABLE meta_public.sites ADD COLUMN  owner_id uuid;

ALTER TABLE meta_public.sites ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE meta_public.sites ADD CONSTRAINT sites_owner_id_fkey FOREIGN KEY ( owner_id ) REFERENCES meta_public.users ( id );

COMMENT ON CONSTRAINT sites_owner_id_fkey ON meta_public.sites IS E'@omit manyToMany';

CREATE INDEX sites_owner_id_idx ON meta_public.sites ( owner_id );

ALTER TABLE meta_public.sites ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_sites ON meta_public.sites FOR SELECT TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_insert_on_sites ON meta_public.sites FOR INSERT TO authenticated WITH CHECK ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_update_on_sites ON meta_public.sites FOR UPDATE TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_delete_on_sites ON meta_public.sites FOR DELETE TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

GRANT SELECT ON TABLE meta_public.sites TO authenticated;

GRANT INSERT ON TABLE meta_public.sites TO authenticated;

GRANT UPDATE ON TABLE meta_public.sites TO authenticated;

GRANT DELETE ON TABLE meta_public.sites TO authenticated;

CREATE TABLE meta_public.api_modules (
  
);

ALTER TABLE meta_public.api_modules DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.api_modules ADD COLUMN  id uuid;

ALTER TABLE meta_public.api_modules ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.api_modules ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.api_modules ADD CONSTRAINT api_modules_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.api_modules ADD COLUMN  name text;

ALTER TABLE meta_public.api_modules ALTER COLUMN name SET NOT NULL;

ALTER TABLE meta_public.api_modules ADD COLUMN  data json;

ALTER TABLE meta_public.api_modules ALTER COLUMN data SET NOT NULL;

ALTER TABLE meta_public.api_modules ADD COLUMN  created_by uuid;

ALTER TABLE meta_public.api_modules ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON meta_public.api_modules 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_peoplestamps (  );

ALTER TABLE meta_public.api_modules ADD COLUMN  created_at timestamptz;

ALTER TABLE meta_public.api_modules ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE meta_public.api_modules ADD COLUMN  updated_at timestamptz;

ALTER TABLE meta_public.api_modules ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON meta_public.api_modules 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_timestamps (  );

ALTER TABLE meta_public.api_modules ADD COLUMN  api_id uuid;

ALTER TABLE meta_public.api_modules ALTER COLUMN api_id SET NOT NULL;

ALTER TABLE meta_public.api_modules ADD CONSTRAINT api_modules_api_id_fkey FOREIGN KEY ( api_id ) REFERENCES meta_public.apis ( id );

COMMENT ON CONSTRAINT api_modules_api_id_fkey ON meta_public.api_modules IS E'@omit manyToMany';

CREATE INDEX api_modules_api_id_idx ON meta_public.api_modules ( api_id );

ALTER TABLE meta_public.api_modules ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_api_modules ON meta_public.api_modules FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.apis AS p WHERE p.id = api_id) );

CREATE POLICY authenticated_can_insert_on_api_modules ON meta_public.api_modules FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.apis AS p WHERE p.id = api_id) );

CREATE POLICY authenticated_can_update_on_api_modules ON meta_public.api_modules FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.apis AS p WHERE p.id = api_id) );

CREATE POLICY authenticated_can_delete_on_api_modules ON meta_public.api_modules FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.apis AS p WHERE p.id = api_id) );

GRANT SELECT ON TABLE meta_public.api_modules TO authenticated;

GRANT INSERT ON TABLE meta_public.api_modules TO authenticated;

GRANT UPDATE ON TABLE meta_public.api_modules TO authenticated;

GRANT DELETE ON TABLE meta_public.api_modules TO authenticated;

CREATE TABLE meta_public.site_modules (
  
);

ALTER TABLE meta_public.site_modules DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.site_modules ADD COLUMN  id uuid;

ALTER TABLE meta_public.site_modules ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.site_modules ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.site_modules ADD CONSTRAINT site_modules_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.site_modules ADD COLUMN  name text;

ALTER TABLE meta_public.site_modules ALTER COLUMN name SET NOT NULL;

ALTER TABLE meta_public.site_modules ADD COLUMN  data json;

ALTER TABLE meta_public.site_modules ALTER COLUMN data SET NOT NULL;

ALTER TABLE meta_public.site_modules ADD COLUMN  created_by uuid;

ALTER TABLE meta_public.site_modules ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON meta_public.site_modules 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_peoplestamps (  );

ALTER TABLE meta_public.site_modules ADD COLUMN  created_at timestamptz;

ALTER TABLE meta_public.site_modules ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE meta_public.site_modules ADD COLUMN  updated_at timestamptz;

ALTER TABLE meta_public.site_modules ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON meta_public.site_modules 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_timestamps (  );

ALTER TABLE meta_public.site_modules ADD COLUMN  site_id uuid;

ALTER TABLE meta_public.site_modules ALTER COLUMN site_id SET NOT NULL;

ALTER TABLE meta_public.site_modules ADD CONSTRAINT site_modules_site_id_fkey FOREIGN KEY ( site_id ) REFERENCES meta_public.sites ( id );

COMMENT ON CONSTRAINT site_modules_site_id_fkey ON meta_public.site_modules IS E'@omit manyToMany';

CREATE INDEX site_modules_site_id_idx ON meta_public.site_modules ( site_id );

ALTER TABLE meta_public.site_modules ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_site_modules ON meta_public.site_modules FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.sites AS p WHERE p.id = site_id) );

CREATE POLICY authenticated_can_insert_on_site_modules ON meta_public.site_modules FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.sites AS p WHERE p.id = site_id) );

CREATE POLICY authenticated_can_update_on_site_modules ON meta_public.site_modules FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.sites AS p WHERE p.id = site_id) );

CREATE POLICY authenticated_can_delete_on_site_modules ON meta_public.site_modules FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.sites AS p WHERE p.id = site_id) );

GRANT SELECT ON TABLE meta_public.site_modules TO authenticated;

GRANT INSERT ON TABLE meta_public.site_modules TO authenticated;

GRANT UPDATE ON TABLE meta_public.site_modules TO authenticated;

GRANT DELETE ON TABLE meta_public.site_modules TO authenticated;

CREATE TABLE meta_public.site_themes (
  
);

ALTER TABLE meta_public.site_themes DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.site_themes ADD COLUMN  id uuid;

ALTER TABLE meta_public.site_themes ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.site_themes ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.site_themes ADD CONSTRAINT site_themes_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.site_themes ADD COLUMN  theme jsonb;

ALTER TABLE meta_public.site_themes ALTER COLUMN theme SET NOT NULL;

ALTER TABLE meta_public.site_themes ADD COLUMN  created_by uuid;

ALTER TABLE meta_public.site_themes ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON meta_public.site_themes 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_peoplestamps (  );

ALTER TABLE meta_public.site_themes ADD COLUMN  created_at timestamptz;

ALTER TABLE meta_public.site_themes ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE meta_public.site_themes ADD COLUMN  updated_at timestamptz;

ALTER TABLE meta_public.site_themes ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON meta_public.site_themes 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_timestamps (  );

ALTER TABLE meta_public.site_themes ADD COLUMN  site_id uuid;

ALTER TABLE meta_public.site_themes ALTER COLUMN site_id SET NOT NULL;

ALTER TABLE meta_public.site_themes ADD CONSTRAINT site_themes_site_id_fkey FOREIGN KEY ( site_id ) REFERENCES meta_public.sites ( id );

COMMENT ON CONSTRAINT site_themes_site_id_fkey ON meta_public.site_themes IS E'@omit manyToMany';

CREATE INDEX site_themes_site_id_idx ON meta_public.site_themes ( site_id );

ALTER TABLE meta_public.site_themes ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_site_themes ON meta_public.site_themes FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.sites AS p WHERE p.id = site_id) );

CREATE POLICY authenticated_can_insert_on_site_themes ON meta_public.site_themes FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.sites AS p WHERE p.id = site_id) );

CREATE POLICY authenticated_can_update_on_site_themes ON meta_public.site_themes FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.sites AS p WHERE p.id = site_id) );

CREATE POLICY authenticated_can_delete_on_site_themes ON meta_public.site_themes FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.sites AS p WHERE p.id = site_id) );

GRANT SELECT ON TABLE meta_public.site_themes TO authenticated;

GRANT INSERT ON TABLE meta_public.site_themes TO authenticated;

GRANT UPDATE ON TABLE meta_public.site_themes TO authenticated;

GRANT DELETE ON TABLE meta_public.site_themes TO authenticated;

CREATE TABLE meta_public.site_metadata (
  
);

ALTER TABLE meta_public.site_metadata DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.site_metadata ADD COLUMN  id uuid;

ALTER TABLE meta_public.site_metadata ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.site_metadata ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.site_metadata ADD CONSTRAINT site_metadata_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.site_metadata ADD COLUMN  title text;

ALTER TABLE meta_public.site_metadata ADD CONSTRAINT site_metadata_title_chk CHECK ( character_length(title) <= 120 );

ALTER TABLE meta_public.site_metadata ADD COLUMN  description text;

ALTER TABLE meta_public.site_metadata ADD CONSTRAINT site_metadata_description_chk CHECK ( character_length(description) <= 120 );

ALTER TABLE meta_public.site_metadata ADD COLUMN  og_image image;

ALTER TABLE meta_public.site_metadata ADD COLUMN  created_by uuid;

ALTER TABLE meta_public.site_metadata ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON meta_public.site_metadata 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_peoplestamps (  );

ALTER TABLE meta_public.site_metadata ADD COLUMN  created_at timestamptz;

ALTER TABLE meta_public.site_metadata ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE meta_public.site_metadata ADD COLUMN  updated_at timestamptz;

ALTER TABLE meta_public.site_metadata ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON meta_public.site_metadata 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_timestamps (  );

ALTER TABLE meta_public.site_metadata ADD COLUMN  site_id uuid;

ALTER TABLE meta_public.site_metadata ALTER COLUMN site_id SET NOT NULL;

ALTER TABLE meta_public.site_metadata ADD CONSTRAINT site_metadata_site_id_fkey FOREIGN KEY ( site_id ) REFERENCES meta_public.sites ( id );

COMMENT ON CONSTRAINT site_metadata_site_id_fkey ON meta_public.site_metadata IS E'@omit manyToMany';

CREATE INDEX site_metadata_site_id_idx ON meta_public.site_metadata ( site_id );

ALTER TABLE meta_public.site_metadata ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_site_metadata ON meta_public.site_metadata FOR SELECT TO authenticated USING ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.sites AS p WHERE p.id = site_id) );

CREATE POLICY authenticated_can_insert_on_site_metadata ON meta_public.site_metadata FOR INSERT TO authenticated WITH CHECK ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.sites AS p WHERE p.id = site_id) );

CREATE POLICY authenticated_can_update_on_site_metadata ON meta_public.site_metadata FOR UPDATE TO authenticated USING ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.sites AS p WHERE p.id = site_id) );

CREATE POLICY authenticated_can_delete_on_site_metadata ON meta_public.site_metadata FOR DELETE TO authenticated USING ( (SELECT p.owner_id = ANY (meta_public.get_current_group_ids()) FROM meta_public.sites AS p WHERE p.id = site_id) );

GRANT SELECT ON TABLE meta_public.site_metadata TO authenticated;

GRANT INSERT ON TABLE meta_public.site_metadata TO authenticated;

GRANT UPDATE ON TABLE meta_public.site_metadata TO authenticated;

GRANT DELETE ON TABLE meta_public.site_metadata TO authenticated;

CREATE TABLE meta_public.apps (
  
);

ALTER TABLE meta_public.apps DISABLE ROW LEVEL SECURITY;

ALTER TABLE meta_public.apps ADD COLUMN  id uuid;

ALTER TABLE meta_public.apps ALTER COLUMN id SET NOT NULL;

ALTER TABLE meta_public.apps ALTER COLUMN id SET DEFAULT meta_private.uuid_generate_v4();

ALTER TABLE meta_public.apps ADD CONSTRAINT apps_pkey PRIMARY KEY ( id );

ALTER TABLE meta_public.apps ADD COLUMN  name text;

ALTER TABLE meta_public.apps ADD COLUMN  app_image image;

ALTER TABLE meta_public.apps ADD COLUMN  app_store_link url;

ALTER TABLE meta_public.apps ADD COLUMN  app_store_id text;

ALTER TABLE meta_public.apps ADD COLUMN  app_id_prefix text;

ALTER TABLE meta_public.apps ADD COLUMN  play_store_link url;

ALTER TABLE meta_public.apps ADD COLUMN  created_by uuid;

ALTER TABLE meta_public.apps ADD COLUMN  updated_by uuid;

CREATE TRIGGER tg_peoplestamps 
 BEFORE INSERT OR UPDATE ON meta_public.apps 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_peoplestamps (  );

ALTER TABLE meta_public.apps ADD COLUMN  created_at timestamptz;

ALTER TABLE meta_public.apps ALTER COLUMN created_at SET DEFAULT now();

ALTER TABLE meta_public.apps ADD COLUMN  updated_at timestamptz;

ALTER TABLE meta_public.apps ALTER COLUMN updated_at SET DEFAULT now();

CREATE TRIGGER tg_timestamps 
 BEFORE INSERT OR UPDATE ON meta_public.apps 
 FOR EACH ROW
 EXECUTE PROCEDURE meta_private. tg_timestamps (  );

ALTER TABLE meta_public.apps ADD COLUMN  owner_id uuid;

ALTER TABLE meta_public.apps ALTER COLUMN owner_id SET NOT NULL;

ALTER TABLE meta_public.apps ADD CONSTRAINT apps_owner_id_fkey FOREIGN KEY ( owner_id ) REFERENCES meta_public.users ( id );

COMMENT ON CONSTRAINT apps_owner_id_fkey ON meta_public.apps IS E'@omit manyToMany';

CREATE INDEX apps_owner_id_idx ON meta_public.apps ( owner_id );

ALTER TABLE meta_public.apps ADD CONSTRAINT apps_name_owner_id_key UNIQUE ( name, owner_id );

COMMENT ON CONSTRAINT apps_name_owner_id_key ON meta_public.apps IS NULL;

ALTER TABLE meta_public.apps ENABLE ROW LEVEL SECURITY;

CREATE POLICY authenticated_can_select_on_apps ON meta_public.apps FOR SELECT TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_insert_on_apps ON meta_public.apps FOR INSERT TO authenticated WITH CHECK ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_update_on_apps ON meta_public.apps FOR UPDATE TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

CREATE POLICY authenticated_can_delete_on_apps ON meta_public.apps FOR DELETE TO authenticated USING ( owner_id = meta_public.get_current_user_id() OR owner_id = ANY (meta_public.get_current_group_ids()) );

GRANT SELECT ON TABLE meta_public.apps TO authenticated;

GRANT INSERT ON TABLE meta_public.apps TO authenticated;

GRANT UPDATE ON TABLE meta_public.apps TO authenticated;

GRANT DELETE ON TABLE meta_public.apps TO authenticated;