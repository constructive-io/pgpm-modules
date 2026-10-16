-- Deploy schemas/function_resolution/procedures/infra_secrets_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/infra_config_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/infra_secrets_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- infra_secrets_module_registrations: the infra_secrets_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: owner_database_id answers a database's own
-- instances, surface_scope a shared surface across databases, and NULL leaves that
-- side unfiltered. Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.infra_secrets_module_registrations(owner_database_id uuid, surface_scope text DEFAULT NULL)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    secrets_table_name text,
    prefix text,
    entity_field text,
    config_entity_field text,
    has_config boolean,
    config_table_name text,
    public_schema text,
    private_schema text,
    config_schema text
) AS $$
SELECT
    ism.database_id,
    (ism.database_id = app_scope.platform_database_id()) AS platform_owned,
    ism.scope,
    ism.secrets_table_name,
    ism.prefix,
    ism.entity_field,
    icm.entity_field AS config_entity_field,
    (icm.id IS NOT NULL) AS has_config,
    cfg_t.name AS config_table_name,
    pub_s.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    cfg_s.schema_name AS config_schema
FROM metaschema_modules_public.infra_secrets_module AS ism
    LEFT JOIN metaschema_modules_public.infra_config_module icm
    ON icm.database_id = ism.database_id
   AND icm.scope = ism.scope
   AND icm.prefix = ism.prefix
    LEFT JOIN metaschema_public.table cfg_t ON cfg_t.id = icm.config_table_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = ism.private_schema_id
    LEFT JOIN metaschema_public.schema pub_s ON pub_s.id = ism.schema_id
    LEFT JOIN metaschema_public.schema cfg_s ON cfg_s.id = icm.schema_id
WHERE ($1 IS NULL OR ism.database_id = $1)
  AND ($2 IS NULL OR ism.scope = $2)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.infra_secrets_module_registrations(uuid, text) FROM PUBLIC;

COMMIT;
