\echo Use "CREATE EXTENSION pgpm-app-scope" to load this file. \quit
CREATE SCHEMA IF NOT EXISTS app_scope;

GRANT USAGE ON SCHEMA app_scope TO administrator;

GRANT USAGE ON SCHEMA app_scope TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA app_scope
  GRANT EXECUTE ON FUNCTIONS TO administrator;

CREATE FUNCTION app_scope.platform_database_id() RETURNS uuid AS $EOFCODE$
DECLARE
  v_database_id uuid;
BEGIN
  SELECT d.id INTO v_database_id
  FROM metaschema_public.database d
  WHERE d.platform;

  IF v_database_id IS NULL THEN
    RAISE EXCEPTION 'PLATFORM_DATABASE_NOT_REGISTERED: no metaschema_public.database row has platform = true';
  END IF;

  RETURN v_database_id;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION app_scope.platform_database_id() IS 'Id of the platform (constructive) database: the singleton metaschema_public.database row with platform = true. Raises PLATFORM_DATABASE_NOT_REGISTERED if none is flagged.';

CREATE FUNCTION app_scope.dyn_lookup_uuid(
  lookup_schema text,
  lookup_table text,
  lookup_column text,
  row_id uuid
) RETURNS uuid AS $EOFCODE$
DECLARE
    v_result uuid;
    v_query text;
BEGIN
    v_query := format(
        'SELECT %I FROM %I.%I WHERE id = $1',
        lookup_column, lookup_schema, lookup_table
    );
    EXECUTE v_query INTO v_result USING row_id;
    RETURN v_result;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION app_scope.membership_parent(
  database_id uuid,
  scope text
) RETURNS TABLE (
  membership_type int,
  parent_scope text,
  entity_schema text,
  entity_table text,
  owner_field text
) AS $EOFCODE$
DECLARE
    v_types_table_id uuid;
    v_types_schema text;
    v_types_table text;
    v_membership_type int;
    v_parent_membership_type int;
    v_parent_scope text;
    v_entity_table_id uuid;
    v_entity_table_owner_id uuid;
    v_query text;
BEGIN
    SELECT mtm.table_id
    INTO v_types_table_id
    FROM metaschema_modules_public.membership_types_module mtm
    WHERE mtm.database_id = membership_parent.database_id;

    IF v_types_table_id IS NULL THEN
        RETURN;
    END IF;

    -- Locate the physical membership_types table (inline schema_and_table).
    SELECT s.schema_name, t.name
    INTO v_types_schema, v_types_table
    FROM metaschema_public.schema s
    JOIN metaschema_public."table" t ON (t.schema_id = s.id AND t.database_id = s.database_id)
    WHERE t.id = v_types_table_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- SELECT id, parent_membership_type FROM "<types>" WHERE scope = $1
    v_query := format(
        'SELECT id, parent_membership_type FROM %I.%I WHERE scope = $1',
        v_types_schema, v_types_table
    );
    EXECUTE v_query INTO v_membership_type, v_parent_membership_type USING membership_parent.scope;

    IF v_membership_type IS NULL THEN
        RETURN;
    END IF;

    -- Resolve the parent scope name (custom/org/app parents alike).
    IF v_parent_membership_type IS NOT NULL THEN
        -- SELECT scope FROM "<types>" WHERE id = $1
        v_query := format(
            'SELECT scope FROM %I.%I WHERE id = $1',
            v_types_schema, v_types_table
        );
        EXECUTE v_query INTO v_parent_scope USING v_parent_membership_type;
    END IF;

    -- Entity table + owner FK for the current scope (static metaschema config).
    SELECT mm.entity_table_id, mm.entity_table_owner_id
    INTO v_entity_table_id, v_entity_table_owner_id
    FROM metaschema_modules_public.memberships_module mm
    WHERE mm.database_id = membership_parent.database_id
      AND mm.scope = membership_parent.scope;

    IF v_entity_table_id IS NOT NULL THEN
        -- inline schema_and_table
        SELECT s.schema_name, t.name
        INTO membership_parent.entity_schema, membership_parent.entity_table
        FROM metaschema_public.schema s
        JOIN metaschema_public."table" t ON (t.schema_id = s.id AND t.database_id = s.database_id)
        WHERE t.id = v_entity_table_id;

        IF v_entity_table_owner_id IS NOT NULL THEN
            -- inline field_name
            SELECT f.name
            INTO membership_parent.owner_field
            FROM metaschema_public.field f
            WHERE f.id = v_entity_table_owner_id
              AND f.table_id = v_entity_table_id;
        END IF;
    END IF;

    membership_parent.membership_type := v_membership_type;
    membership_parent.parent_scope := v_parent_scope;
    RETURN NEXT;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION app_scope.local_frames(
  database_id uuid,
  execution_scope text,
  entity_id uuid DEFAULT NULL
) RETURNS TABLE (
  scope text,
  lookup_database_id uuid,
  key_value uuid
) AS $EOFCODE$
DECLARE
    v_exec text;
    v_current_scope text;
    v_current_key uuid;
    v_info record;
    v_parent_key uuid;
    v_org_id uuid;
    v_safety_counter int := 0;
BEGIN
    IF execution_scope IS NULL THEN
        RAISE EXCEPTION 'APP_SCOPE_LOCAL_FRAMES_SCOPE_REQUIRED: execution_scope is required (no default scope)';
    END IF;

    v_exec := execution_scope;

    -- `platform` is the cross-database terminal, never a within-database frame.
    IF v_exec = 'platform' THEN
        RETURN;
    END IF;

    IF v_exec = 'app' THEN
        scope := 'app';
        lookup_database_id := database_id;
        key_value := NULL;
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_exec = 'org' THEN
        scope := 'org';
        lookup_database_id := database_id;
        key_value := entity_id;
        RETURN NEXT;

        scope := 'app';
        lookup_database_id := database_id;
        key_value := NULL;
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_exec = 'database' THEN
        -- database frame keyed by the database itself (synthetic root).
        scope := 'database';
        lookup_database_id := database_id;
        key_value := database_id;
        RETURN NEXT;

        -- The organization that OWNS this database (database.owner_id) — the
        -- bridge from the hardcoded database root into the scope tree.
        SELECT d.owner_id INTO v_org_id
        FROM metaschema_public.database d
        WHERE d.id = local_frames.database_id;

        IF v_org_id IS NOT NULL THEN
            scope := 'org';
            lookup_database_id := database_id;
            key_value := v_org_id;
            RETURN NEXT;
        END IF;

        scope := 'app';
        lookup_database_id := database_id;
        key_value := NULL;
        RETURN NEXT;
        RETURN;
    END IF;

    -- Custom entity scope: its own frame, then walk the membership tree up to
    -- (and including) the owning org, emitting each parent frame, then app.
    scope := v_exec;
    lookup_database_id := database_id;
    key_value := entity_id;
    RETURN NEXT;

    v_current_scope := v_exec;
    v_current_key := entity_id;
    LOOP
        v_safety_counter := v_safety_counter + 1;
        IF v_safety_counter > 32 THEN
            RAISE EXCEPTION 'APP_SCOPE_LOCAL_FRAMES_DEPTH_EXCEEDED: scope chain exceeded 32 hops from scope "%" (database_id=%)',
                execution_scope, database_id;
        END IF;

        SELECT * INTO v_info
        FROM app_scope.membership_parent(local_frames.database_id, v_current_scope);

        -- Not a membership scope, or already at org/app: stop climbing.
        EXIT WHEN v_info.membership_type IS NULL;
        EXIT WHEN v_info.membership_type <= 2;

        -- Climb: resolve the parent entity id via the current owner FK.
        EXIT WHEN v_info.parent_scope IS NULL
            OR v_info.entity_schema IS NULL
            OR v_info.owner_field IS NULL
            OR v_current_key IS NULL;

        v_parent_key := app_scope.dyn_lookup_uuid(
            v_info.entity_schema, v_info.entity_table, v_info.owner_field, v_current_key
        );
        EXIT WHEN v_parent_key IS NULL;

        v_current_scope := v_info.parent_scope;
        v_current_key := v_parent_key;

        scope := v_current_scope;
        lookup_database_id := database_id;
        key_value := v_current_key;
        RETURN NEXT;
    END LOOP;

    -- This database's global app frame.
    scope := 'app';
    lookup_database_id := database_id;
    key_value := NULL;
    RETURN NEXT;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION app_scope.local_frames(uuid, text, uuid) IS 'Ordered scope-lookup frames WITHIN one database (most specific first) from the given execution scope up through that database''s global `app` scope: entity -> (membership climb) -> org -> app, or database -> org -> app, or org -> app, or app. Never emits the cross-database `platform` terminal — app_scope.frames appends that. `database` is the synthetic per-database root (keyed by the database, owned by database.owner_id); entity scopes climb their membership tree straight to the owning org.';

CREATE FUNCTION app_scope.frames(
  database_id uuid,
  execution_scope text,
  entity_id uuid DEFAULT NULL
) RETURNS TABLE (
  scope text,
  lookup_database_id uuid,
  key_value uuid
) AS $EOFCODE$
DECLARE
    v_platform_db uuid;
    v_is_platform_db boolean;
BEGIN
    -- Hard contract: the execution scope is always known at the call site (a
    -- scope-aware trigger lives on exactly one per-scope table, so its scope is a
    -- provisioning-time constant). A NULL scope is a caller bug, never a case to
    -- silently reinterpret as 'database'.
    IF execution_scope IS NULL THEN
        RAISE EXCEPTION 'APP_SCOPE_FRAMES_SCOPE_REQUIRED: execution_scope is required (no default scope)';
    END IF;

    -- The platform database is resolved lazily: before it is registered (the
    -- generation bootstrap window, or an isolated generated metaschema), the
    -- execution database is its own root and the chain ends after its local
    -- frames. Only the `platform` execution scope requires the registration.
    SELECT d.id INTO v_platform_db
    FROM metaschema_public.database d
    WHERE d.platform;

    v_is_platform_db := (frames.database_id = v_platform_db);

    -- `platform` execution scope names the global root directly: nothing is more
    -- or less specific to walk, so the chain is just the terminal platform frame.
    IF execution_scope = 'platform' THEN
        IF v_platform_db IS NULL THEN
            RAISE EXCEPTION 'PLATFORM_DATABASE_NOT_REGISTERED: no metaschema_public.database row has platform = true';
        END IF;
        scope := 'platform';
        lookup_database_id := v_platform_db;
        key_value := NULL;
        RETURN NEXT;
        RETURN;
    END IF;

    -- The execution database's own local chain (entity -> ... -> org -> app, or
    -- database -> org -> app).
    RETURN QUERY
    SELECT lf.scope, lf.lookup_database_id, lf.key_value
    FROM app_scope.local_frames(frames.database_id, frames.execution_scope, frames.entity_id) lf;

    -- No platform database registered: the local chain ends the search.
    IF v_platform_db IS NULL THEN
        RETURN;
    END IF;

    -- Fall through to the platform database's OWN full local chain (its
    -- database -> org -> app), unless the execution already ran inside the
    -- platform database (in which case its local chain above already covered it).
    -- The fall-through `database` frame is re-keyed by the EXECUTION database:
    -- `database` is the synthetic per-database root, so rows a tenant reads or
    -- writes on a shared plane served by this frame are keyed by the tenant's
    -- own database_id, never by the platform database that hosts the plane.
    IF NOT v_is_platform_db THEN
        RETURN QUERY
        SELECT lf.scope, lf.lookup_database_id,
               CASE WHEN lf.scope = 'database' THEN frames.database_id
                    ELSE lf.key_value END
        FROM app_scope.local_frames(v_platform_db, 'database', NULL) lf;
    END IF;

    -- The single global root: the platform terminal, resolved in the platform
    -- database.
    scope := 'platform';
    lookup_database_id := v_platform_db;
    key_value := NULL;
    RETURN NEXT;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION app_scope.frames(uuid, text, uuid) IS 'Ordered scope-lookup frames for an execution, most-specific first. A database is the unit of resolution: each database climbs its own local chain (entity -> ... -> org -> app, or database -> org -> app) via app_scope.local_frames; a tenant execution then falls through to the platform database''s own full chain (database -> org -> app) and finally the single global `platform` terminal. The platform database is the root database, not a special case. Each frame carries the scope-key VALUE to match against a consuming module''s entity_field (global app/platform frames carry NULL) and the lookup_database_id whose module instance the frame is probed in. Single source of truth for scope resolution; never hand-order scopes or re-derive keys elsewhere. The platform database is resolved lazily: before one is registered (generation bootstrap, isolated metaschemas) the chain ends after the local frames, and only the `platform` execution scope raises PLATFORM_DATABASE_NOT_REGISTERED.';

CREATE FUNCTION app_scope.routing_tables(
  database_id uuid,
  scope text
) RETURNS TABLE (
  apis_schema text,
  apis_table text,
  api_schemas_schema text,
  api_schemas_table text,
  api_modules_schema text,
  api_modules_table text,
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
) AS $EOFCODE$
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

    SELECT am.apis_table_id, am.api_schemas_table_id, am.api_modules_table_id,
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
               api_modules_s.schema_name, api_modules_t.name,
               api_settings_s.schema_name, api_settings_t.name,
               cors_settings_s.schema_name, cors_settings_t.name
        INTO apis_schema, apis_table,
             api_schemas_schema, api_schemas_table,
             api_modules_schema, api_modules_table,
             api_settings_schema, api_settings_table,
             cors_settings_schema, cors_settings_table
        FROM metaschema_public.table apis_t
        JOIN metaschema_public.schema apis_s ON apis_s.id = apis_t.schema_id
        JOIN metaschema_public.table api_schemas_t ON api_schemas_t.id = api_surface.api_schemas_table_id
        JOIN metaschema_public.schema api_schemas_s ON api_schemas_s.id = api_schemas_t.schema_id
        JOIN metaschema_public.table api_modules_t ON api_modules_t.id = api_surface.api_modules_table_id
        JOIN metaschema_public.schema api_modules_s ON api_modules_s.id = api_modules_t.schema_id
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
$EOFCODE$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION app_scope.routing_tables(uuid, text) IS 'Physical (schema, table) names of the scoped routing source/settings tables serving an execution at the given scope, resolved from the api_surface_module, site_surface_module, domain_module, route_module and app_module registrations. Scope resolution one layer above app_scope.frames: each surface is located independently by walking frames (exact-scope frames first, then most-specific first), so an inner frame''s apis surface never hijacks the domain/site/route planes served by an outer frame. No platform special-casing. Surfaces not provisioned on any frame come back NULL; a registration pointing at a missing table raises ROUTING_TABLES_NOT_FOUND.';