-- Deploy schemas/function_resolution/procedures/install_route_bindings to pg
-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/resolve
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/site_surface_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/route_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/resource_module/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/routing_tables

BEGIN;

-- install_route_bindings: install a set of route bindings onto one site, at ONE
-- scope, for ONE entity.
--
-- This is the one engine behind every "point these paths at what we just
-- deployed" verb: the platform's own Mantra page set (function targets, through
-- function_resolution.install_mantra) and a deployment graph binding the paths
-- of a service it just released (service targets). A binding is ordinary route
-- data either way — a row in the scope's routes plane whose typed target column
-- carries the id the routing resolver already answers — so this is a pure data
-- write and there is nothing to reconcile here: the routes plane's own job
-- trigger enqueues http_route:reconcile.
--
-- The bindings document is a JSON array whose every entry NAMES ITS TARGET KIND:
--
--   {"path": "/login", "target": "function", "task_identifier": "mantra:signin", "anonymous": true}
--   {"path": "/app",   "target": "service",  "service_id": "<uuid>"}
--
-- An entry may declare `anonymous`, which is the route's half of the anonymous
-- contract: the URL answers callers carrying no identity. It opens nothing on
-- its own — the definition behind it must declare anonymous_callable too — and
-- defaults to false, so a document that says nothing installs closed routes.
--
-- The kind is never inferred from which key happens to be present, and an entry
-- carrying keys for two kinds is a malformed document rather than a precedence
-- question: guessing is how a deployment silently binds /app to the wrong plane.
--
-- The single-scope invariant, unchanged from the function-only engine it
-- generalises. Nothing here takes a scope literal from a caller or bakes one
-- into generated SQL. The caller names the physical sites plane it belongs to;
-- the scope and the ownership key column are then read off that plane's own
-- module registration (site_surface_module.scope / .entity_field, stamped at
-- provisioning time by metaschema_generators.scope_key_column), and that one
-- (scope, key value) is what every subsequent step uses:
--
--   * app_scope.routing_tables(database_id, scope) names the routes plane
--     serving that scope — so the routes written are the ones that scope's
--     resolver reads, never another frame's plane;
--   * the site row and its existing route are read pinned to the key value, so
--     a SECURITY DEFINER wrapper cannot reach another tenant's or another
--     entity's site;
--   * function_resolution.resolve starts at that same (scope, entity), so a
--     nearer frame publishing a task shadows an outer one FOR THAT ENTITY and
--     nobody else;
--   * a service target is proved to exist in the SAME-SCOPE resources plane —
--     the one this database's resource_module registers AT THAT SCOPE, which is
--     the source plane route_module gives target_service_id its FK against —
--     pinned to that plane's own recorded key, so a binding cannot point a
--     route at another tenant's or another entity's service;
--   * every inserted route stamps that same key value.
--
-- The serving site is stamped the same registration-driven way. A routing plane
-- may carry a column saying which site's surface a route renders as, and its
-- route_module registration records that column's name (serving_site_field,
-- stamped by the generator that created the field). When it is recorded, every
-- route this install touches — inserted or already present, since a path the
-- document also claims is still a path this site serves — carries the site the
-- bindings were installed onto; when it is not, nothing is stamped. So the fact
-- travels with the plane rather than living in whatever verb happens to call
-- this, and this module still knows no column name of its own.
--
-- Ownership tiers, from the plane's recorded entity_field:
--   entity_field IS NULL       global tier — ownerless rows, no key stamped
--   entity_field = database_id database tier — keyed by the executing database
--   entity_field = <entity>_id entity tier  — keyed by the entity_id argument,
--                                             which is then required
--
-- Idempotent by construction: each insert carries a NOT EXISTS guard on the
-- route's (domain_id, path) key, so re-running after the document grows installs
-- only what is missing and never repoints a route a tenant has since edited.
--
-- Fail-loud throughout: an unregistered plane, a scope with no routes plane, a
-- missing entity key, an unknown site, a site with no route to layer onto, a
-- malformed bindings document, an unknown or ambiguous target kind, an
-- unresolvable service, and an unpublished task each raise. Nothing is skipped
-- silently.
--
-- The dynamic SQL is the same case as resolve_api's: the relation is named by
-- the caller's plane and proved to exist by an ordinary catalog join first, and
-- no value is ever interpolated — only verified relation and column names.
CREATE FUNCTION function_resolution.install_route_bindings(
    database_id uuid,
    sites_schema text,
    sites_table text,
    site_id uuid,
    bindings jsonb,
    entity_id uuid DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
    -- plane_scope, not scope: the module registrations this reads all carry a
    -- scope column, and a local named scope makes every one of those predicates
    -- ambiguous.
    plane_scope text;
    sites_key text;
    routes_schema text;
    routes_table text;
    routes_key text;
    -- The routes column carrying the serving site, from the plane's own
    -- registration. NULL for a plane that has none, which makes the stamp a
    -- no-op rather than an error.
    routes_serving_site_key text;
    stamped int := 0;
    -- The same-scope resources plane a service binding must resolve within, and
    -- its own recorded ownership key. NULL when this scope carries no resources
    -- plane, which makes a service binding a hard error rather than an
    -- unchecked insert.
    resources_schema text;
    resources_table text;
    resources_key text;
    -- The one ownership key value the whole install is keyed by (NULL at the
    -- global tier), and the entity the resolver starts its frame walk at.
    key_value uuid;
    resolution_entity uuid;
    site_found boolean;
    domain_id uuid;
    -- Per-binding state: the entry, its declared kind, and the id the route's
    -- typed target column gets, together with the column that carries it.
    entry jsonb;
    entry_path text;
    entry_target text;
    entry_task text;
    entry_service uuid;
    entry_anonymous boolean;
    target_column text;
    target_id uuid;
    service_found boolean;
    inserted int;
    installed jsonb := '[]'::jsonb;
    skipped jsonb := '[]'::jsonb;
    query text;
BEGIN
    IF install_route_bindings.database_id IS NULL THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_DATABASE_REQUIRED: database_id is required'
            USING ERRCODE = 'FR050';
    END IF;

    IF install_route_bindings.sites_schema IS NULL OR install_route_bindings.sites_table IS NULL THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_SITES_PLANE_REQUIRED: sites_schema and sites_table are required'
            USING ERRCODE = 'FR050';
    END IF;

    IF install_route_bindings.site_id IS NULL THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_SITE_REQUIRED: site_id is required'
            USING ERRCODE = 'FR050';
    END IF;

    -- The bindings document, validated before anything is written: an empty or
    -- wrongly-shaped document is a broken install, not a no-op.
    IF install_route_bindings.bindings IS NULL
       OR jsonb_typeof(install_route_bindings.bindings) <> 'array'
       OR jsonb_array_length(install_route_bindings.bindings) = 0 THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_INVALID: bindings must be a non-empty JSON array of {path, target, …}, got %',
            coalesce(jsonb_typeof(install_route_bindings.bindings), 'null')
            USING ERRCODE = 'FR060';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(install_route_bindings.bindings) AS b
        WHERE jsonb_typeof(b) <> 'object'
           OR coalesce(b ->> 'path', '') = ''
           OR coalesce(b ->> 'target', '') = ''
    ) THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_INVALID: every binding must carry a non-empty path and target'
            USING ERRCODE = 'FR060';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(install_route_bindings.bindings) AS b
        WHERE (b ->> 'target') NOT IN ('function', 'service')
    ) THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_TARGET_UNKNOWN: target must be "function" or "service"'
            USING ERRCODE = 'FR060';
    END IF;

    -- A binding carrying the key of a kind it did not declare is ambiguous, and
    -- resolving it by precedence would let a typo repoint a path at a different
    -- plane than the document reads like.
    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(install_route_bindings.bindings) AS b
        WHERE (b ? 'task_identifier') AND (b ? 'service_id')
           OR (b ->> 'target') = 'function' AND (b ? 'service_id')
           OR (b ->> 'target') = 'service' AND (b ? 'task_identifier')
    ) THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_TARGET_AMBIGUOUS: a binding must carry only the key of the target kind it declares'
            USING ERRCODE = 'FR060';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(install_route_bindings.bindings) AS b
        WHERE (b ->> 'target') = 'function' AND coalesce(b ->> 'task_identifier', '') = ''
           OR (b ->> 'target') = 'service' AND coalesce(b ->> 'service_id', '') = ''
    ) THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_INVALID: a function binding needs a task_identifier and a service binding needs a service_id'
            USING ERRCODE = 'FR060';
    END IF;

    -- A service_id is cast to uuid before it is looked up, and a bare cast
    -- failure reports "invalid input syntax for type uuid" with no hint of which
    -- binding carried it — so the document is rejected by name instead.
    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(install_route_bindings.bindings) AS b
        WHERE (b ->> 'target') = 'service'
          AND (b ->> 'service_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    ) THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_SERVICE_INVALID: a service binding''s service_id must be a uuid'
            USING ERRCODE = 'FR060';
    END IF;

    -- Idempotency is keyed by (domain_id, path), so two entries claiming one
    -- path would install the first and report the second as already-there —
    -- a document that reads like it bound both. It is malformed instead.
    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(install_route_bindings.bindings) AS b
        GROUP BY b ->> 'path'
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_PATH_DUPLICATED: a path may be bound once per document'
            USING ERRCODE = 'FR060';
    END IF;

    -- 1. The plane's own registration decides the scope. This is the whole
    --    point: the scope is a recorded fact about the sites plane being
    --    installed onto, not a caller-supplied string and not a literal frozen
    --    into a generated body.
    --
    --    The registration is looked up ALONG THE CALLER'S FRAMES, the same walk
    --    step 2 resolves the routes plane with, because a sites plane serving a
    --    scope is not necessarily registered in the database consuming it: the
    --    database-scope serving planes are shared, hosted by an outer frame's
    --    database and keyed per tenant, so a tenant installing onto the plane it
    --    is actually served by has no registration of its own to find. Keying is
    --    unaffected — the scope comes from the registration and the key value from
    --    the caller (step 3), so a tenant's rows stay stamped with the tenant.
    --    Nearest frame wins, so a plane a database does register still resolves to
    --    its own registration.
    SELECT sm.scope, sm.entity_field
    INTO plane_scope, sites_key
    FROM app_scope.frames(install_route_bindings.database_id, 'database') WITH ORDINALITY AS f
    JOIN metaschema_modules_public.site_surface_module AS sm
      ON sm.scope = f.scope
     AND sm.database_id = f.lookup_database_id
    JOIN metaschema_public."table" AS t ON t.id = sm.sites_table_id
    JOIN metaschema_public.schema AS s ON s.id = t.schema_id
    WHERE s.schema_name = install_route_bindings.sites_schema
      AND t.name = install_route_bindings.sites_table
    ORDER BY f.ordinality
    LIMIT 1;

    IF plane_scope IS NULL THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_SITES_PLANE_NOT_REGISTERED: no site_surface_module on any frame of database % registers %.% as its sites plane',
            install_route_bindings.database_id, install_route_bindings.sites_schema, install_route_bindings.sites_table
            USING ERRCODE = 'FR051';
    END IF;

    -- 2. The routes plane serving THAT scope, resolved the one way every
    --    scope-aware consumer resolves it.
    SELECT r.routes_schema, r.routes_table
    INTO routes_schema, routes_table
    FROM app_scope.routing_tables(install_route_bindings.database_id, plane_scope) AS r;

    IF routes_schema IS NULL OR routes_table IS NULL THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_ROUTES_PLANE_NOT_FOUND: scope "%" has no routes plane provisioned on any frame of database %',
            plane_scope, install_route_bindings.database_id
            USING ERRCODE = 'FR051';
    END IF;

    -- The routes plane's own registration carries its ownership key and, when
    -- the plane has one, the column naming the site a route renders as.
    SELECT rm.entity_field, rm.serving_site_field
    INTO routes_key, routes_serving_site_key
    FROM metaschema_modules_public.route_module AS rm
    JOIN metaschema_public."table" AS t ON t.id = rm.routes_table_id
    JOIN metaschema_public.schema AS s ON s.id = t.schema_id
    WHERE s.schema_name = routes_schema
      AND t.name = routes_table;

    -- Both planes are at the same scope, so scope_key_column gave them the same
    -- ownership key. A mismatch means the registrations disagree about who owns
    -- the rows, which is exactly the cross-scope write this function exists to
    -- make impossible.
    IF routes_key IS DISTINCT FROM sites_key THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_PLANE_KEY_MISMATCH: sites plane %.% is keyed by % but routes plane %.% is keyed by %',
            install_route_bindings.sites_schema, install_route_bindings.sites_table, coalesce(sites_key, '<none>'),
            routes_schema, routes_table, coalesce(routes_key, '<none>')
            USING ERRCODE = 'FR051';
    END IF;

    -- The resources plane serving that same scope, from its own module
    -- registration: target_service_id FKs this scope's source resources table,
    -- so this is the plane the constraint would check a service binding against.
    SELECT s.schema_name, t.name, rem.entity_field
    INTO resources_schema, resources_table, resources_key
    FROM metaschema_modules_public.resource_module AS rem
    JOIN metaschema_public."table" AS t ON t.id = rem.resources_table_id
    JOIN metaschema_public.schema AS s ON s.id = t.schema_id
    WHERE rem.database_id = install_route_bindings.database_id
      AND rem.scope = plane_scope;

    -- 3. One key value for the whole operation.
    IF sites_key IS NULL THEN
        key_value := NULL;
        resolution_entity := NULL;
    ELSIF sites_key = 'database_id' THEN
        key_value := install_route_bindings.database_id;
        resolution_entity := NULL;
    ELSE
        IF install_route_bindings.entity_id IS NULL THEN
            RAISE EXCEPTION 'ROUTE_BINDINGS_ENTITY_REQUIRED: scope "%" is keyed by %, so entity_id is required',
                plane_scope, sites_key
                USING ERRCODE = 'FR052';
        END IF;
        key_value := install_route_bindings.entity_id;
        resolution_entity := install_route_bindings.entity_id;
    END IF;

    -- 4. The site, pinned to that key value.
    -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the sites plane is named by the caller and proved by the registration join above
    query := format(
        'SELECT EXISTS (SELECT 1 FROM %I.%I AS s WHERE s.id = $1%s)',
        install_route_bindings.sites_schema,
        install_route_bindings.sites_table,
        CASE WHEN sites_key IS NULL
             THEN ' AND $2 IS NULL'
             ELSE format(' AND s.%I = $2', sites_key)
        END
    );

    EXECUTE query INTO site_found USING install_route_bindings.site_id, key_value;

    IF NOT site_found THEN
        RAISE EXCEPTION 'SITE_NOT_FOUND: no site % in %.% owned by %',
            install_route_bindings.site_id, install_route_bindings.sites_schema, install_route_bindings.sites_table,
            coalesce(key_value::text, plane_scope)
            USING ERRCODE = 'FR053';
    END IF;

    -- 5. The hostname the site already serves. Bindings layer onto an existing
    --    site route rather than claiming a hostname of their own: the root-route
    --    guard auto-creates '/' carrying the target of a hostname's FIRST route,
    --    so installing onto a bare hostname would make '/' the first binding's
    --    target. A site that is not routed yet is a hard error, not a silently
    --    empty install.
    -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the routes plane is named by app_scope.routing_tables
    query := format(
        'SELECT r.domain_id FROM %I.%I AS r WHERE r.target_site_id = $1%s ORDER BY r.path LIMIT 1',
        routes_schema,
        routes_table,
        CASE WHEN routes_key IS NULL
             THEN ' AND $2 IS NULL'
             ELSE format(' AND r.%I = $2', routes_key)
        END
    );

    EXECUTE query INTO domain_id USING install_route_bindings.site_id, key_value;

    IF domain_id IS NULL THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_SITE_NOT_ROUTED: site % serves no hostname in %.%, so there is nowhere to install the bindings',
            install_route_bindings.site_id, routes_schema, routes_table
            USING ERRCODE = 'FR054';
    END IF;

    -- 6. Per binding: resolve the declared target at THIS (scope, entity) and
    --    install the route if it is not already there.
    FOR entry IN SELECT * FROM jsonb_array_elements(install_route_bindings.bindings)
    LOOP
        entry_path := entry ->> 'path';
        entry_target := entry ->> 'target';
        entry_anonymous := coalesce((entry ->> 'anonymous')::boolean, false);

        IF entry_target = 'function' THEN
            entry_task := entry ->> 'task_identifier';

            -- Fail-loud by the resolver's own contract: an unpublished task
            -- raises FUNCTION_DEFINITION_NOT_FOUND rather than installing a
            -- route that would 404 at request time.
            SELECT fr.function_definition_id
            INTO target_id
            FROM function_resolution.resolve(
                install_route_bindings.database_id,
                plane_scope,
                resolution_entity,
                entry_task
            ) AS fr;

            target_column := 'target_function_id';
        ELSE
            entry_service := (entry ->> 'service_id')::uuid;

            IF resources_schema IS NULL THEN
                RAISE EXCEPTION 'ROUTE_BINDINGS_SERVICE_PLANE_NOT_FOUND: database % has no resource_module at scope "%", so there is no plane a service target could live in',
                    install_route_bindings.database_id, plane_scope
                    USING ERRCODE = 'FR055';
            END IF;

            -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the resources plane is named by this scope's own resource_module registration
            query := format(
                'SELECT EXISTS (SELECT 1 FROM %I.%I AS r WHERE r.id = $1%s)',
                resources_schema,
                resources_table,
                CASE WHEN resources_key IS NULL
                     THEN ' AND $2 IS NULL'
                     ELSE format(' AND r.%I = $2', resources_key)
                END
            );

            EXECUTE query INTO service_found USING entry_service, key_value;

            IF NOT service_found THEN
                RAISE EXCEPTION 'ROUTE_BINDINGS_SERVICE_NOT_FOUND: no service % in %.% owned by %',
                    entry_service, resources_schema, resources_table,
                    coalesce(key_value::text, plane_scope)
                    USING ERRCODE = 'FR056';
            END IF;

            target_id := entry_service;
            target_column := 'target_service_id';
        END IF;

        -- pgsql-lint-disable-next-line no-dynamic-sql -- write-only: insert into the routes plane named by app_scope.routing_tables; every value is a bound parameter
        query := format(
            'INSERT INTO %I.%I (%s%sdomain_id, path, anonymous, %I)
             SELECT %s%s$1, $2, $6, $3
              WHERE NOT EXISTS (
                    SELECT 1 FROM %I.%I AS x
                     WHERE x.domain_id = $1 AND x.path = $2%s)',
            routes_schema,
            routes_table,
            CASE WHEN routes_key IS NULL THEN '' ELSE format('%I, ', routes_key) END,
            CASE WHEN routes_serving_site_key IS NULL THEN '' ELSE format('%I, ', routes_serving_site_key) END,
            target_column,
            CASE WHEN routes_key IS NULL THEN '' ELSE '$4, ' END,
            CASE WHEN routes_serving_site_key IS NULL THEN '' ELSE '$5, ' END,
            routes_schema,
            routes_table,
            CASE WHEN routes_key IS NULL
                 THEN ' AND $4 IS NULL'
                 ELSE format(' AND x.%I = $4', routes_key)
            END
        );

        EXECUTE query USING domain_id, entry_path, target_id, key_value,
            install_route_bindings.site_id, entry_anonymous;
        GET DIAGNOSTICS inserted = ROW_COUNT;

        IF inserted > 0 THEN
            installed := installed || jsonb_build_array(entry_path);
        ELSE
            skipped := skipped || jsonb_build_array(entry_path);
        END IF;
    END LOOP;

    -- Backfill the serving site onto the paths that were already there: the
    -- insert above stamps what it writes, and a route the document claims but
    -- did not create is still a route this site serves. IS DISTINCT FROM keeps a
    -- repeat install a no-op write rather than a row version per path, and the
    -- ownership pin repeats here so a SECURITY DEFINER caller cannot stamp a row
    -- another owner holds even if a domain were ever shared across planes.
    IF routes_serving_site_key IS NOT NULL AND jsonb_array_length(skipped) > 0 THEN
        -- pgsql-lint-disable-next-line no-dynamic-sql -- write-only: update the routes plane named by app_scope.routing_tables; every value is a bound parameter
        query := format(
            'UPDATE %I.%I AS r
                SET %I = $1
              WHERE r.domain_id = $2
                AND $3 @> to_jsonb(r.path)
                AND r.%I IS DISTINCT FROM $1%s',
            routes_schema,
            routes_table,
            routes_serving_site_key,
            routes_serving_site_key,
            CASE WHEN routes_key IS NULL
                 THEN ' AND $4 IS NULL'
                 ELSE format(' AND r.%I = $4', routes_key)
            END
        );

        EXECUTE query USING install_route_bindings.site_id, domain_id, skipped, key_value;
        GET DIAGNOSTICS stamped = ROW_COUNT;
    END IF;

    RETURN jsonb_build_object(
        'site_id', install_route_bindings.site_id,
        'scope', plane_scope,
        'entity_id', install_route_bindings.entity_id,
        'domain_id', domain_id,
        'routes_schema', routes_schema,
        'routes_table', routes_table,
        'installed', installed,
        'skipped', skipped,
        'serving_site_field', routes_serving_site_key,
        'serving_site_backfilled', stamped
    );
END;
$$ LANGUAGE plpgsql VOLATILE;

COMMENT ON FUNCTION function_resolution.install_route_bindings(uuid, text, text, uuid, jsonb, uuid) IS
'Install a set of route bindings — a JSON array of {path, target, …} entries, each NAMING its target kind ("function" with a task_identifier, or "service" with a service_id) — onto one site as ordinary route rows, at ONE scope for ONE entity. The scope and ownership key are read from the named sites plane''s own site_surface_module registration, located along the caller''s frames (nearest first) so a shared serving plane hosted by an outer frame''s database resolves for the tenant consuming it — never a caller-supplied or generated literal — and that one (scope, key) then names the routes plane (app_scope.routing_tables), pins the site, route and service reads, starts function_resolution.resolve''s frame walk, and stamps every inserted row; a service target is proved to exist in the same-scope resources plane the routes plane''s registration records, which is the plane target_service_id FKs. Idempotent per (domain_id, path); raises on a malformed document, an unknown or ambiguous target kind, an unregistered plane, a scope with no routes plane, a missing entity key, an unknown site, an unrouted site, a scope with no resources plane, an unresolvable service, or an unpublished task.';

COMMIT;
