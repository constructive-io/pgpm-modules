-- Deploy schemas/app_scope/procedures/routing_tables to pg
-- requires: schemas/app_scope/schema
-- requires: schemas/app_scope/procedures/frames

BEGIN;

-- routing_tables: the physical (schema, table) names of the scoped routing
-- source/settings tables serving an execution at the given scope, resolved
-- from the module registrations (api_surface_module, site_surface_module,
-- domain_module, route_module, app_module).
--
-- This is scope resolution, one layer above app_scope.frames: frames answers
-- "which frames does this execution see, most-specific first", and this answers
-- "which physical tables do those frames put in front of it". It belongs beside
-- frames for the same reason frames exists — so no consumer hand-orders scopes
-- or re-derives keys.
--
-- The scope is a required caller-passed parameter. Each surface's module
-- instance is located by walking app_scope.frames (exact-scope frames first,
-- then most-specific first): the first frame with THAT surface's module
-- registered at (lookup_database_id, frame scope) wins, independently per
-- surface — a database's own app-scope apis surface must not hijack the
-- domain/site/route planes served by an outer frame. There is no platform
-- special-casing; the frame walk is the single source of truth. Columns for
-- surfaces not provisioned on any frame come back NULL, so writers can guard
-- with IS NOT NULL checks.
--
-- Portable: reads only the metaschema catalog (metaschema-schema /
-- metaschema-modules) and calls sibling app_scope functions. The table_id ->
-- (schema_name, table_name) resolution is joined inline rather than delegated,
-- because metaschema-utils sits downstream of this package and depending on it
-- would be a cycle. Each surface resolves all of its ids in one statement, so a
-- registration pointing at a missing table fails loudly instead of silently
-- yielding NULL names.
CREATE FUNCTION app_scope.routing_tables(
    database_id uuid,
    scope text
) RETURNS TABLE (
    apis_schema text,
    apis_table text,
    api_schemas_schema text,
    api_schemas_table text,
    api_settings_schema text,
    api_settings_table text,
    cors_settings_schema text,
    cors_settings_table text,
    sites_schema text,
    sites_table text,
    site_metadata_schema text,
    site_metadata_table text,
    site_modules_schema text,
    site_modules_table text,
    site_themes_schema text,
    site_themes_table text,
    domains_schema text,
    domains_table text,
    managed_domains_schema text,
    managed_domains_table text,
    routes_schema text,
    routes_table text,
    apps_schema text,
    apps_table text,
    apps_key_column text
) AS $$
DECLARE
    api_surface record;
    site_surface record;
    domain_surface record;
    route_surface record;
    app_surface record;
BEGIN
    -- Hard contract, matching app_scope.frames: the scope is always known at the
    -- call site. A NULL scope is a caller bug, never a silent 'database'.
    IF routing_tables.scope IS NULL THEN
        RAISE EXCEPTION 'ROUTING_TABLES_SCOPE_REQUIRED: scope is required (no default scope)';
    END IF;

    SELECT am.apis_table_id, am.api_schemas_table_id,
           am.api_settings_table_id, am.cors_settings_table_id
    INTO api_surface
    FROM app_scope.frames(
        routing_tables.database_id,
        routing_tables.scope
    ) WITH ORDINALITY f
    JOIN metaschema_modules_public.api_surface_module am
      ON am.scope = f.scope
     AND am.database_id = f.lookup_database_id
    ORDER BY (f.scope = routing_tables.scope) DESC, f.ordinality
    LIMIT 1;

    IF FOUND AND api_surface.apis_table_id IS NOT NULL AND api_surface.apis_table_id <> uuid_nil() THEN
        SELECT apis_s.schema_name, apis_t.name,
               api_schemas_s.schema_name, api_schemas_t.name,
               api_settings_s.schema_name, api_settings_t.name,
               cors_settings_s.schema_name, cors_settings_t.name
        INTO apis_schema, apis_table,
             api_schemas_schema, api_schemas_table,
             api_settings_schema, api_settings_table,
             cors_settings_schema, cors_settings_table
        FROM metaschema_public.table apis_t
        JOIN metaschema_public.schema apis_s ON apis_s.id = apis_t.schema_id
        JOIN metaschema_public.table api_schemas_t ON api_schemas_t.id = api_surface.api_schemas_table_id
        JOIN metaschema_public.schema api_schemas_s ON api_schemas_s.id = api_schemas_t.schema_id
        JOIN metaschema_public.table api_settings_t ON api_settings_t.id = api_surface.api_settings_table_id
        JOIN metaschema_public.schema api_settings_s ON api_settings_s.id = api_settings_t.schema_id
        JOIN metaschema_public.table cors_settings_t ON cors_settings_t.id = api_surface.cors_settings_table_id
        JOIN metaschema_public.schema cors_settings_s ON cors_settings_s.id = cors_settings_t.schema_id
        WHERE apis_t.id = api_surface.apis_table_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'ROUTING_TABLES_NOT_FOUND: api_surface_module registration references a missing table';
        END IF;
    END IF;

    SELECT sm.sites_table_id, sm.site_metadata_table_id,
           sm.site_modules_table_id, sm.site_themes_table_id
    INTO site_surface
    FROM app_scope.frames(
        routing_tables.database_id,
        routing_tables.scope
    ) WITH ORDINALITY f
    JOIN metaschema_modules_public.site_surface_module sm
      ON sm.scope = f.scope
     AND sm.database_id = f.lookup_database_id
    ORDER BY (f.scope = routing_tables.scope) DESC, f.ordinality
    LIMIT 1;

    IF FOUND AND site_surface.sites_table_id IS NOT NULL AND site_surface.sites_table_id <> uuid_nil() THEN
        SELECT sites_s.schema_name, sites_t.name,
               site_metadata_s.schema_name, site_metadata_t.name,
               site_modules_s.schema_name, site_modules_t.name,
               site_themes_s.schema_name, site_themes_t.name
        INTO sites_schema, sites_table,
             site_metadata_schema, site_metadata_table,
             site_modules_schema, site_modules_table,
             site_themes_schema, site_themes_table
        FROM metaschema_public.table sites_t
        JOIN metaschema_public.schema sites_s ON sites_s.id = sites_t.schema_id
        JOIN metaschema_public.table site_metadata_t ON site_metadata_t.id = site_surface.site_metadata_table_id
        JOIN metaschema_public.schema site_metadata_s ON site_metadata_s.id = site_metadata_t.schema_id
        JOIN metaschema_public.table site_modules_t ON site_modules_t.id = site_surface.site_modules_table_id
        JOIN metaschema_public.schema site_modules_s ON site_modules_s.id = site_modules_t.schema_id
        JOIN metaschema_public.table site_themes_t ON site_themes_t.id = site_surface.site_themes_table_id
        JOIN metaschema_public.schema site_themes_s ON site_themes_s.id = site_themes_t.schema_id
        WHERE sites_t.id = site_surface.sites_table_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'ROUTING_TABLES_NOT_FOUND: site_surface_module registration references a missing table';
        END IF;
    END IF;

    SELECT dm.domains_table_id, dm.managed_domains_table_id
    INTO domain_surface
    FROM app_scope.frames(
        routing_tables.database_id,
        routing_tables.scope
    ) WITH ORDINALITY f
    JOIN metaschema_modules_public.domain_module dm
      ON dm.scope = f.scope
     AND dm.database_id = f.lookup_database_id
    ORDER BY (f.scope = routing_tables.scope) DESC, f.ordinality
    LIMIT 1;

    IF FOUND AND domain_surface.domains_table_id IS NOT NULL AND domain_surface.domains_table_id <> uuid_nil() THEN
        SELECT domains_s.schema_name, domains_t.name,
               managed_domains_s.schema_name, managed_domains_t.name
        INTO domains_schema, domains_table,
             managed_domains_schema, managed_domains_table
        FROM metaschema_public.table domains_t
        JOIN metaschema_public.schema domains_s ON domains_s.id = domains_t.schema_id
        JOIN metaschema_public.table managed_domains_t ON managed_domains_t.id = domain_surface.managed_domains_table_id
        JOIN metaschema_public.schema managed_domains_s ON managed_domains_s.id = managed_domains_t.schema_id
        WHERE domains_t.id = domain_surface.domains_table_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'ROUTING_TABLES_NOT_FOUND: domain_module registration references a missing table';
        END IF;
    END IF;

    SELECT rm.routes_table_id
    INTO route_surface
    FROM app_scope.frames(
        routing_tables.database_id,
        routing_tables.scope
    ) WITH ORDINALITY f
    JOIN metaschema_modules_public.route_module rm
      ON rm.scope = f.scope
     AND rm.database_id = f.lookup_database_id
    ORDER BY (f.scope = routing_tables.scope) DESC, f.ordinality
    LIMIT 1;

    IF FOUND AND route_surface.routes_table_id IS NOT NULL AND route_surface.routes_table_id <> uuid_nil() THEN
        SELECT routes_s.schema_name, routes_t.name
        INTO routes_schema, routes_table
        FROM metaschema_public.table routes_t
        JOIN metaschema_public.schema routes_s ON routes_s.id = routes_t.schema_id
        WHERE routes_t.id = route_surface.routes_table_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'ROUTING_TABLES_NOT_FOUND: route_module registration references a missing table';
        END IF;
    END IF;

    SELECT am.apps_table_id, am.entity_field
    INTO app_surface
    FROM app_scope.frames(
        routing_tables.database_id,
        routing_tables.scope
    ) WITH ORDINALITY f
    JOIN metaschema_modules_public.app_module am
      ON am.scope = f.scope
     AND am.database_id = f.lookup_database_id
    ORDER BY (f.scope = routing_tables.scope) DESC, f.ordinality
    LIMIT 1;

    IF FOUND AND app_surface.apps_table_id IS NOT NULL AND app_surface.apps_table_id <> uuid_nil() THEN
        SELECT apps_s.schema_name, apps_t.name
        INTO apps_schema, apps_table
        FROM metaschema_public.table apps_t
        JOIN metaschema_public.schema apps_s ON apps_s.id = apps_t.schema_id
        WHERE apps_t.id = app_surface.apps_table_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'ROUTING_TABLES_NOT_FOUND: app_module registration references a missing table';
        END IF;

        apps_key_column := app_surface.entity_field;
    END IF;

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION app_scope.routing_tables(uuid, text) IS
'Physical (schema, table) names of the scoped routing source/settings tables serving an execution at the given scope, resolved from the api_surface_module, site_surface_module, domain_module, route_module and app_module registrations. Scope resolution one layer above app_scope.frames: each surface is located independently by walking frames (exact-scope frames first, then most-specific first), so an inner frame''s apis surface never hijacks the domain/site/route planes served by an outer frame. No platform special-casing. Surfaces not provisioned on any frame come back NULL; a registration pointing at a missing table raises ROUTING_TABLES_NOT_FOUND.';

COMMIT;
