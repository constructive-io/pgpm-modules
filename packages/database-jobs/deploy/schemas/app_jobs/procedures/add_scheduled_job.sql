-- Deploy schemas/app_jobs/procedures/add_scheduled_job to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: pgpm-jwt-claims:schemas/jwt_private/procedures/current_entity_id
-- requires: pgpm-jwt-claims:schemas/jwt_private/procedures/current_entity_type
-- requires: pgpm-jwt-claims:schemas/jwt_private/procedures/require_database_id
-- requires: pgpm-jwt-claims:schemas/jwt_private/procedures/assert_attribution
-- requires: pgpm-jwt-claims:schemas/jwt_public/procedures/current_user_id
-- requires: pgpm-jwt-claims:schemas/jwt_public/procedures/current_principal_id

BEGIN;

CREATE FUNCTION app_jobs.add_scheduled_job(
  identifier text,
  payload json DEFAULT '{}'::json,
  schedule_info json DEFAULT '{}'::json,
  job_key text DEFAULT NULL,
  queue_name text DEFAULT NULL,
  max_attempts integer DEFAULT 25,
  priority integer DEFAULT 0,
  entity_id uuid DEFAULT jwt_private.current_entity_id(),
  db_id uuid DEFAULT jwt_private.require_database_id(),
  entity_type text DEFAULT jwt_private.current_entity_type(),
  -- The organization is never a claim: it is derived from the entity pair by
  -- get_organization_id at the point of recording, so only a caller that
  -- already resolved it (a data-job trigger with an entity field) passes one.
  organization_id uuid DEFAULT NULL,
  actor_id uuid DEFAULT jwt_public.current_user_id(),
  principal_id uuid DEFAULT jwt_public.current_principal_id()
)
  RETURNS app_jobs.scheduled_jobs
  AS $$
DECLARE
  v_job app_jobs.scheduled_jobs;
  v_database_id uuid;
  v_actor_id uuid;
  v_principal_id uuid;
BEGIN
  -- db_id defaults to the session's database claim; only callers that act on
  -- behalf of a different database (e.g. provisioning triggers, platform-owned
  -- births) pass it explicitly. Every scheduled job is owned by exactly one
  -- database — a claim-less session with no explicit db_id fails the
  -- scheduled_jobs.database_id NOT NULL constraint rather than producing an
  -- unattributable job.
  v_database_id := db_id;
  v_actor_id := add_scheduled_job.actor_id;
  v_principal_id := add_scheduled_job.principal_id;
  PERFORM jwt_private.assert_attribution(
    v_actor_id,
    add_scheduled_job.entity_id,
    add_scheduled_job.entity_type
  );

  IF job_key IS NOT NULL THEN

    -- Upsert job
    INSERT INTO app_jobs.scheduled_jobs (
      database_id,
      actor_id,
      principal_id,
      entity_id,
      organization_id,
      entity_type,
      task_identifier,
      payload,
      queue_name,
      schedule_info,
      max_attempts,
      key,
      priority
      ) VALUES (
        v_database_id,
        v_actor_id,
        v_principal_id,
        add_scheduled_job.entity_id,
        add_scheduled_job.organization_id,
        add_scheduled_job.entity_type,
        identifier,
        coalesce(payload, '{}'::json),
        queue_name,
        schedule_info,
        coalesce(max_attempts, 25),
        job_key,
        coalesce(priority, 0)
    )
    ON CONFLICT (key)
      DO UPDATE SET
        database_id = EXCLUDED.database_id,
        actor_id = EXCLUDED.actor_id,
        principal_id = EXCLUDED.principal_id,
        entity_id = EXCLUDED.entity_id,
        organization_id = EXCLUDED.organization_id,
        entity_type = EXCLUDED.entity_type,
        task_identifier = EXCLUDED.task_identifier,
        payload = EXCLUDED.payload,
        queue_name = EXCLUDED.queue_name,
        max_attempts = EXCLUDED.max_attempts,
        schedule_info = EXCLUDED.schedule_info,
        priority = EXCLUDED.priority
      WHERE
        scheduled_jobs.locked_at IS NULL
      RETURNING
        * INTO v_job;

    -- If upsert succeeded (insert or update), return early

    IF NOT (v_job IS NULL) THEN
      RETURN v_job;
    END IF;

    -- Upsert failed -> there must be an existing scheduled job that is locked. Remove
    -- and allow a new one to be inserted

    DELETE FROM
      app_jobs.scheduled_jobs
    WHERE
      KEY = job_key;
  END IF;

  INSERT INTO app_jobs.scheduled_jobs (
    database_id,
    actor_id,
    principal_id,
    entity_id,
    organization_id,
    entity_type,
    task_identifier,
    payload,
    queue_name,
    schedule_info,
    max_attempts,
    priority
    ) VALUES (
    v_database_id,
    v_actor_id,
    v_principal_id,
    add_scheduled_job.entity_id,
    add_scheduled_job.organization_id,
    add_scheduled_job.entity_type,
    identifier,
    payload,
    queue_name,
    schedule_info,
    max_attempts,
    priority
  ) RETURNING * INTO v_job;
  RETURN v_job;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE
SECURITY DEFINER;
COMMIT;
