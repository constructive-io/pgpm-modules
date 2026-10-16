-- Deploy schemas/function_resolution/procedures/phone_numbers_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/phone_numbers_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- phone_numbers_module_registrations: the phone_numbers_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.phone_numbers_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    public_schema text,
    phone_numbers_table_name text
) AS $$
SELECT
    pm.database_id,
    (pm.database_id = app_scope.platform_database_id()) AS platform_owned,
    ps.schema_name AS public_schema,
    phone_t.name AS phone_numbers_table_name
FROM metaschema_modules_public.phone_numbers_module AS pm
    LEFT JOIN metaschema_public.schema ps ON ps.id = pm.schema_id
    LEFT JOIN metaschema_public.table phone_t
    ON phone_t.id = pm.table_id AND pm.table_id <> uuid_nil()
WHERE pm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.phone_numbers_module_registrations(uuid) FROM PUBLIC;

COMMIT;
