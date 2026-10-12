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
-- pgpm-defaults deploys before every other module (errors and pgpm-verify
-- require it), so every function a module creates starts with no EXECUTE and
-- is callable only by the roles its generator grants. The native extensions
-- the request roles call (citext operators, pgcrypto, postgis, ...) are listed
-- in pgpm-defaults.control so they are created ahead of this revoke and keep
-- PUBLIC EXECUTE. A per-schema default cannot do this: PostgreSQL adds
-- per-schema default privileges to the database-wide ones, never subtracts.
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
-- No schema-wide function grants here. Schema public holds only extension
-- functions (which carry PUBLIC=X from before the revoke above) and the
-- pgpm-verify deploy-time helpers, so granting a role every function in it
-- adds nothing but a blanket grant. Application function grants are declared
-- per function.
COMMIT;
