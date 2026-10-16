-- Deploy schemas/function_resolution/procedures/pages_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/pages_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id
-- requires: inflection-db:schemas/inflection_db/procedures/get_field_name

BEGIN;

-- pages_module_registrations: the pages_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.pages_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    public_schema text,
    page_published_function text
) AS $$
SELECT
    pm.database_id,
    (pm.database_id = app_scope.platform_database_id()) AS platform_owned,
    pm.scope,
    ps.schema_name AS public_schema,
    inflection_db.get_field_name(ARRAY[pm.prefix, 'page', 'published']) AS page_published_function
FROM metaschema_modules_public.pages_module AS pm
    LEFT JOIN metaschema_public.schema ps ON ps.id = pm.public_schema_id
WHERE pm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.pages_module_registrations(uuid) FROM PUBLIC;

COMMIT;
