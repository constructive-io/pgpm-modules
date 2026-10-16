-- Deploy schemas/function_resolution/procedures/site_surface_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/site_surface_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- site_surface_module_registrations: the site_surface_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.site_surface_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    entity_field text,
    public_schema text,
    private_schema text,
    sites_table_name text,
    site_metadata_table_name text,
    site_themes_table_name text,
    site_modules_table_name text
) AS $$
SELECT
    ssm.database_id,
    (ssm.database_id = app_scope.platform_database_id()) AS platform_owned,
    ssm.scope,
    ssm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    sites_t.name AS sites_table_name,
    meta_t.name AS site_metadata_table_name,
    themes_t.name AS site_themes_table_name,
    mods_t.name AS site_modules_table_name
FROM metaschema_modules_public.site_surface_module AS ssm
    LEFT JOIN metaschema_public.schema ps ON ps.id = ssm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = ssm.private_schema_id
    LEFT JOIN metaschema_public.table sites_t
    ON sites_t.id = ssm.sites_table_id AND ssm.sites_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table meta_t
    ON meta_t.id = ssm.site_metadata_table_id AND ssm.site_metadata_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table themes_t
    ON themes_t.id = ssm.site_themes_table_id AND ssm.site_themes_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table mods_t
    ON mods_t.id = ssm.site_modules_table_id AND ssm.site_modules_table_id <> uuid_nil()
WHERE ssm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.site_surface_module_registrations(uuid) FROM PUBLIC;

COMMIT;
