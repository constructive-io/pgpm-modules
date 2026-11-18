-- Deploy schemas/function_resolution/procedures/events_entry to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/events_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table

BEGIN;

-- events_entry: where one database's app-scope event recorder lives — its
-- private schema and the names of its record_event and record_error
-- functions — for the GraphQL server's refusal recording.
--
-- The module registration and the metaschema row it points at sit behind
-- member RLS, so this is the narrow hop past it: names only, granted to no
-- request role, called only by the platform login. The recorder itself is
-- still called by the request's own role. No row means the database installs
-- no app-scope events module.
CREATE FUNCTION function_resolution.events_entry(database_id uuid)
RETURNS TABLE (
    private_schema_name text,
    record_event text,
    record_error text
) AS $$
SELECT
    s.schema_name::text,
    em.record_event,
    em.record_error
FROM metaschema_modules_public.events_module AS em
    JOIN metaschema_public.schema AS s ON s.id = em.private_schema_id
WHERE em.database_id = $1
  AND em.scope = 'app'
LIMIT 1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.events_entry(uuid) FROM PUBLIC;

COMMIT;
