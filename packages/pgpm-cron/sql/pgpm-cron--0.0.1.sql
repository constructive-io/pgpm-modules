\echo Use "CREATE EXTENSION pgpm-cron" to load this file. \quit
CREATE SCHEMA pgpm_cron;

CREATE FUNCTION pgpm_cron.sync_scheduled_cron() RETURNS void AS $EOFCODE$
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
$EOFCODE$ LANGUAGE plpgsql VOLATILE;