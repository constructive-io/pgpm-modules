-- Deploy schemas/function_resolution/procedures/compute_entry to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/function_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/function_invocation_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table

BEGIN;

-- compute_entry: one database's function surfaces, one row per scope that
-- installs both a function module and its invocation ledger — the schemas and
-- relation names the GraphQL server needs to resolve an API's function
-- bindings and record an invocation.
--
-- The module registrations and the metaschema rows they point at sit behind
-- member RLS, so this is the narrow hop past it: names only, granted to no
-- request role, called only by the platform login. The bindings and the
-- invocations themselves are still read and written by the request's own role
-- under RLS. No row means the database installs no function surface.
CREATE FUNCTION function_resolution.compute_entry(database_id uuid)
RETURNS TABLE (
    functions_schema_name text,
    definitions_table_name text,
    bindings_table_name text,
    invocations_schema_name text,
    invocations_table_name text,
    invocations_entity_field text
) AS $$
SELECT
    fs.schema_name::text,
    fm.definitions_table_name,
    fm.bindings_table_name,
    ivs.schema_name::text,
    ivm.invocations_table_name,
    ivm.entity_field
FROM metaschema_modules_public.function_module AS fm
    JOIN metaschema_public.schema AS fs ON fs.id = fm.schema_id
    JOIN metaschema_modules_public.function_invocation_module AS ivm
    ON ivm.database_id = fm.database_id AND ivm.scope = fm.scope
    JOIN metaschema_public.schema AS ivs ON ivs.id = ivm.schema_id
WHERE fm.database_id = $1
ORDER BY fs.schema_name
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.compute_entry(uuid) FROM PUBLIC;

COMMIT;
