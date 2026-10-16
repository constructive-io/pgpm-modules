-- Deploy schemas/function_resolution/procedures/database_settings_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/database_settings_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- database_settings_module_registrations: the database_settings_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.database_settings_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    entity_field text,
    public_schema text,
    database_settings_table_name text,
    rls_settings_table_name text
) AS $$
SELECT
    dsm.database_id,
    (dsm.database_id = app_scope.platform_database_id()) AS platform_owned,
    dsm.scope,
    dsm.entity_field,
    ps.schema_name AS public_schema,
    settings_t.name AS database_settings_table_name,
    rls_t.name AS rls_settings_table_name
FROM metaschema_modules_public.database_settings_module AS dsm
    LEFT JOIN metaschema_public.schema ps ON ps.id = dsm.schema_id
    LEFT JOIN metaschema_public.table settings_t
    ON settings_t.id = dsm.database_settings_table_id
    AND dsm.database_settings_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table rls_t
    ON rls_t.id = dsm.rls_settings_table_id AND dsm.rls_settings_table_id <> uuid_nil()
WHERE dsm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.database_settings_module_registrations(uuid) FROM PUBLIC;

COMMIT;
