-- Deploy schemas/pgpm_cron/procedures/sync_scheduled_cron to pg

-- requires: schemas/pgpm_cron/schema
-- requires: metaschema-schema:schemas/metaschema_public/tables/scheduled_cron/table

BEGIN;

-- Reconcile the declarative metaschema_public.scheduled_cron registry into
-- pg_cron for the local (single-database) deployment shape, where pg_cron lives
-- in the same database that owns the scheduled_cron rows. Open-code only: safe
-- to ship to exported/consumer databases. The platform cross-database case
-- (one pg_cron fanning out via cron.schedule_in_database) is handled by the
-- platform deploy flow, not here.
--
-- database_id is intentionally not consulted: in the local shape every row
-- belongs to the one database running the sync.
CREATE FUNCTION pgpm_cron.sync_scheduled_cron()
  RETURNS void
  AS $$
DECLARE
  v_row record;
BEGIN
  -- pg_cron lives in one database per cluster (the cron database), so it is
  -- absent in most databases this module ships to. Where absent, the registry
  -- is still the source of truth for an external scheduler; nothing to do here.
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RETURN;
  END IF;

  FOR v_row IN
    SELECT name, schedule, command, is_enabled
      FROM metaschema_public.scheduled_cron
  LOOP
    IF v_row.is_enabled THEN
      PERFORM cron.schedule(v_row.name, v_row.schedule, v_row.command);
    ELSIF EXISTS (SELECT 1 FROM cron.job WHERE jobname = v_row.name) THEN
      PERFORM cron.unschedule(v_row.name);
    END IF;
  END LOOP;
END;
$$
LANGUAGE 'plpgsql' VOLATILE;

COMMIT;
