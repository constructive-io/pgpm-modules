-- Deploy schemas/function_resolution/procedures/route_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/catalog_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/route_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- route_module_registrations: the route_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: owner_database_id answers a database's own
-- instances, surface_scope a shared surface across databases, and NULL leaves that
-- side unfiltered. Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.route_module_registrations(owner_database_id uuid, surface_scope text DEFAULT NULL)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    routes_table_name text,
    redirects_table_name text,
    hostname_bindings_table_name text,
    route_bindings_table_name text,
    resolver_function_name text,
    app_links_function_name text,
    deep_link_function_name text,
    entity_field text,
    public_schema text,
    private_schema text,
    sites_catalog_table_name text,
    sites_catalog_schema text
) AS $$
SELECT
    rm.database_id,
    (rm.database_id = app_scope.platform_database_id()) AS platform_owned,
    rm.scope,
    rm.routes_table_name,
    rm.redirects_table_name,
    rm.hostname_bindings_table_name,
    rm.route_bindings_table_name,
    rm.resolver_function_name,
    rm.app_links_function_name,
    rm.deep_link_function_name,
    rm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    sites_t.name AS sites_catalog_table_name,
    sites_s.schema_name AS sites_catalog_schema
FROM metaschema_modules_public.route_module AS rm
    LEFT JOIN metaschema_public.schema ps ON ps.id = rm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = rm.private_schema_id
    LEFT JOIN metaschema_modules_public.catalog_module cm ON cm.id = rm.catalog_module_id
    LEFT JOIN metaschema_public.table sites_t
    ON sites_t.id = cm.sites_table_id
   AND cm.sites_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.schema sites_s ON sites_s.id = sites_t.schema_id
WHERE ($1 IS NULL OR rm.database_id = $1)
  AND ($2 IS NULL OR rm.scope = $2)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.route_module_registrations(uuid, text) FROM PUBLIC;

COMMIT;
