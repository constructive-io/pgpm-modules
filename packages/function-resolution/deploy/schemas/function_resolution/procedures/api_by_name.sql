-- Deploy schemas/function_resolution/procedures/api_by_name to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table

BEGIN;

-- api_by_name: one database's api by its name, with its exposed schemas, for
-- the platform's own request router answering the trusted private X-Api-Name
-- header before any request identity exists.
--
-- routing_public.apis and api_schemas sit behind member RLS, so this is the
-- narrow hop past it: granted to no request role, called only by the platform
-- login on its own connection with no role switch. An unknown database or api
-- name returns no row, which the router answers with a 404.

CREATE FUNCTION function_resolution.api_by_name(database_id uuid, api_name text)
RETURNS TABLE (
    api_id uuid,
    api_database_id uuid,
    dbname text,
    role_name text,
    anon_role text,
    is_public boolean,
    schemas text[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT a.id, a.database_id, a.dbname::text, a.role_name::text, a.anon_role::text, a.is_published,
           COALESCE(array_agg(s.schema_name::text ORDER BY s.schema_name) FILTER (WHERE s.schema_name IS NOT NULL), '{}')
    FROM routing_public.apis AS a
    LEFT JOIN routing_public.api_schemas AS aps ON aps.api_id = a.id
    LEFT JOIN metaschema_public.schema AS s ON s.id = aps.schema_id
    WHERE a.database_id = api_by_name.database_id
      AND a.name = api_by_name.api_name
    GROUP BY a.id, a.database_id, a.dbname, a.role_name, a.anon_role, a.is_published;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.api_by_name(uuid, text) FROM PUBLIC;

COMMIT;
