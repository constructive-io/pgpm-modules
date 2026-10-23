-- Deploy schemas/partman/default_privileges to pg

BEGIN;

-- pg_partman creates template + child tables in the partman schema over time
-- (create_parent, run_maintenance). Default privileges keep those future
-- objects reachable by the authenticated role. The one-time GRANTs on the
-- extension's existing objects live in extensions.json (provides.grants).

-- partman.part_config's CHECK constraints call these three as the writer.
-- Every other partman function is reached only through a reviewed
-- SECURITY DEFINER caller (partman_after_insert_partition, run_maintenance).
GRANT EXECUTE ON FUNCTION partman.check_automatic_maintenance_value(text) TO authenticated;
GRANT EXECUTE ON FUNCTION partman.check_epoch_type(text) TO authenticated;
GRANT EXECUTE ON FUNCTION partman.check_partition_type(text) TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA partman
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

COMMIT;
