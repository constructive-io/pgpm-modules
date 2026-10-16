-- Deploy schemas/function_resolution/procedures/cors_origins to pg

-- requires: schemas/function_resolution/schema

BEGIN;

-- cors_origins: the allowed CORS origins for one database and API, the API's
-- own row first and the database default (api_id IS NULL) otherwise, for the
-- GraphQL server answering a preflight before any request identity exists.
--
-- routing_public.cors_settings sits behind member RLS, so this is the narrow
-- hop past it: granted to no request role, called only by the platform login.
-- No row means the database has no CORS settings.

CREATE FUNCTION function_resolution.cors_origins(database_id uuid, api_id uuid)
RETURNS TABLE (
    allowed_origins text[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT cs.allowed_origins
    FROM routing_public.cors_settings AS cs
    WHERE cs.database_id = cors_origins.database_id
      AND (cs.api_id = cors_origins.api_id OR cs.api_id IS NULL)
    ORDER BY cs.api_id IS NULL
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.cors_origins(uuid, uuid) FROM PUBLIC;

COMMIT;
