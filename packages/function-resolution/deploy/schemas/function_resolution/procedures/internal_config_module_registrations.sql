-- Deploy schemas/function_resolution/procedures/internal_config_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/internal_config_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- internal_config_module_registrations: the internal_config_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.internal_config_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    entity_field text,
    prefix text,
    config_table_name text,
    public_schema text,
    private_schema text
) AS $$
SELECT
    icm.database_id,
    (icm.database_id = app_scope.platform_database_id()) AS platform_owned,
    icm.scope,
    icm.entity_field,
    icm.prefix,
    cfg_t.name AS config_table_name,
    pub_s.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.internal_config_module AS icm
    LEFT JOIN metaschema_public.table cfg_t ON cfg_t.id = icm.internal_config_table_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = icm.private_schema_id
    LEFT JOIN metaschema_public.schema pub_s ON pub_s.id = icm.schema_id
WHERE icm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.internal_config_module_registrations(uuid) FROM PUBLIC;

COMMIT;
