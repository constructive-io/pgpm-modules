-- Deploy pgpm-defaults:defaults/public to pg

BEGIN;
DO $$
DECLARE
  sql text;
BEGIN
  SELECT
    format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database()) INTO sql;
  EXECUTE sql;
END
$$;
-- NOTE: don't alter this as new schemas inherit this behavior
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
-- No schema-wide function grants here. Schema public holds only extension
-- functions (which carry PUBLIC=X from before the revoke above) and the
-- pgpm-verify deploy-time helpers, so granting a role every function in it
-- adds nothing but a blanket grant. Application function grants are declared
-- per function.
COMMIT;
