-- Deploy schemas/function_resolution/procedures/sessions_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/sessions_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- sessions_module_registrations: the sessions_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.sessions_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    private_schema text,
    auth_settings_table_name text,
    sessions_table_name text,
    session_credentials_table_name text
) AS $$
SELECT
    sm.database_id,
    (sm.database_id = app_scope.platform_database_id()) AS platform_owned,
    pvs.schema_name AS private_schema,
    settings_t.name AS auth_settings_table_name,
    sessions_t.name AS sessions_table_name,
    credentials_t.name AS session_credentials_table_name
FROM metaschema_modules_public.sessions_module AS sm
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = sm.schema_id
    LEFT JOIN metaschema_public.table settings_t
    ON settings_t.id = sm.auth_settings_table_id AND sm.auth_settings_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table sessions_t ON sessions_t.id = sm.sessions_table_id
    LEFT JOIN metaschema_public.table credentials_t
    ON credentials_t.id = sm.session_credentials_table_id
WHERE sm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.sessions_module_registrations(uuid) FROM PUBLIC;

COMMIT;
