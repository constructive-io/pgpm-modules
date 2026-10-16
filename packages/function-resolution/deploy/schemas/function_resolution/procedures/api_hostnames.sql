-- Deploy schemas/function_resolution/procedures/api_hostnames to pg

-- requires: schemas/function_resolution/schema

BEGIN;

-- api_hostnames: every hostname routing_public.domains serves for a database,
-- so the platform's request router can evict exactly that database's cached
-- hosts when its schema is flushed.
--
-- The domains table sits behind member RLS, so this is the narrow hop past it:
-- granted to no request role, called only by the platform login on its own
-- connection with no role switch.

CREATE FUNCTION function_resolution.api_hostnames(database_id uuid)
RETURNS SETOF text AS $$
BEGIN
    RETURN QUERY
    SELECT d.hostname::text
    FROM routing_public.domains AS d
    WHERE d.database_id = api_hostnames.database_id
      AND d.hostname IS NOT NULL
    ORDER BY 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.api_hostnames(uuid) FROM PUBLIC;

COMMIT;
