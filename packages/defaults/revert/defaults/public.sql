-- Revert pgpm-defaults:defaults/public from pg

BEGIN;

-- Restores PostgreSQL's out-of-the-box PUBLIC privileges.
GRANT CREATE ON SCHEMA public TO PUBLIC;
ALTER DEFAULT PRIVILEGES GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
DO $$
DECLARE
  sql text;
BEGIN
  SELECT
    format('GRANT CONNECT, TEMPORARY ON DATABASE %I TO PUBLIC', current_database()) INTO sql;
  EXECUTE sql;
END
$$;

COMMIT;
