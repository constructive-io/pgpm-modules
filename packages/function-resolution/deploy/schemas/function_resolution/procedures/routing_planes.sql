-- Deploy schemas/function_resolution/procedures/routing_planes to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/route_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table

BEGIN;

-- routing_planes: every database-scope routing plane, in the fixed order a
-- host is resolved against them (database_id), for the platform's own request
-- router before any request identity exists.
--
-- It enumerates every tenant database, so it is granted to no request role:
-- only the platform login (granted at provision) calls it, on its own
-- connection with no role switch. A plane whose route_module names no schema
-- or no resolver is returned as-is so the caller fails loudly on it.
CREATE FUNCTION function_resolution.routing_planes()
RETURNS TABLE (
    database_id uuid,
    schema_name text,
    resolver_function_name text
) AS $$
    SELECT
        rm.database_id,
        s.schema_name::text,
        rm.resolver_function_name
    FROM metaschema_modules_public.route_module AS rm
    LEFT JOIN metaschema_public.schema AS s ON s.id = rm.schema_id
    WHERE rm.scope = 'database'
    ORDER BY rm.database_id
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.routing_planes() FROM PUBLIC;

COMMIT;
