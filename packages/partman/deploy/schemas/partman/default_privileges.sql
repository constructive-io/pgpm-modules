-- Deploy schemas/partman/default_privileges to pg

BEGIN;

-- pg_partman creates template + child tables in the partman schema over time
-- (create_parent, run_maintenance). Default privileges keep those future
-- objects reachable by the authenticated role. The one-time GRANTs on the
-- extension's existing objects live in extensions.json (provides.grants).
ALTER DEFAULT PRIVILEGES IN SCHEMA partman
  GRANT EXECUTE ON FUNCTIONS TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA partman
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

COMMIT;
