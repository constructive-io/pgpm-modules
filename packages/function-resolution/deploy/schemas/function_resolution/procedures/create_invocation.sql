-- Deploy schemas/function_resolution/procedures/create_invocation to pg
-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/resolve
-- requires: schemas/function_resolution/procedures/definitions_location
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/function_invocation_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/route_module/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/frames
-- requires: pgpm-app-scope:schemas/app_scope/procedures/routing_tables
-- requires: pgpm-jwt-claims:schemas/jwt_private/procedures/require_database_id
-- requires: pgpm-jwt-claims:schemas/jwt_public/procedures/current_user_id

BEGIN;

-- create_invocation: the one sanctioned way a REQUEST-role session opens a
-- ledger row for a sync invocation.
--
-- The sync gateway inserts the invocation under the caller's own role —
-- authenticated when the request carries an identity, anonymous when it does
-- not — because a request's ledger row is the request's own write and no
-- gateway should hold a general RLS bypass. Every SSO lane starts pre-login
-- (the session probe, the sign-in/sign-up pages), so "anonymous" is an ordinary
-- request shape here, not an exception. But an invocations plane grants INSERT
-- to authenticated only, and its permissive arm additionally wants app-admin
-- membership, so both the anonymous lanes AND ordinary signed-in callers are
-- locked out of their own ledger.
--
-- Rather than widen the table (a broad anonymous policy, or a bypass role that
-- can write any row anywhere), this follows the platform's existing pre-login
-- precedent — authenticate / sign_in_identity / sign_up_identity are SECURITY
-- DEFINER functions granted to anonymous — and makes the WRITE itself the
-- narrow surface: one row, in the addressed database's own invocations plane,
-- for a task that database's frames actually publish on the sync channel, and
-- for an anonymous caller only when the definition DECLARES itself callable
-- without an identity and the route it arrived through DECLARES itself
-- anonymous.
--
-- What is checked, in order, all of it fail-loud:
--
--   1. the session's database claim IS the addressed database — a SECURITY
--      DEFINER function is RLS-exempt, so this is the tenant boundary and it is
--      checked first, not inferred from a policy that no longer applies;
--   2. the task resolves to a definition across that (database, scope, entity)
--      frame chain — an unpublished or unknown task never reaches the ledger;
--   3. the winning definition declares the sync channel (access_channels), read
--      from its OWN home plane, which is transport eligibility;
--   4. anonymous callers additionally prove authorization, twice over: the
--      winning definition declares anonymous_callable — the code consenting to
--      run for a caller carrying no identity — and the route binding the
--      gateway resolved this request through exists on the routes plane serving
--      that scope, is active, targets THAT definition, is owned by the same
--      key, and declares anonymous access. Neither half opens anything alone: a
--      route cannot publish a definition that never consented, and a consenting
--      definition is still only reachable at a URL that says so.
--      access_channels is neither half — it says a lane may carry the call,
--      never who may make it — and the route id is validated here rather than
--      trusted from the caller.
--
-- The row is then inserted into the plane the module registration names, keyed
-- by the column that registration records (entity_field, stamped at
-- provisioning by metaschema_generators.scope_key_column): the database itself
-- at database scope, the owning entity at an entity scope, no key column at a
-- global scope. Actor/entity attribution is NOT accepted as an argument and NOT
-- stamped here — identity rides the transaction, and the plane's own BEFORE
-- INSERT trigger fills actor_id / principal_id / entity_id / entity_type from
-- the claims and asserts attribution, exactly as it does for every other
-- ingress path. That trigger also resolves and stamps the winning
-- (function_definition_id, definition_scope) pair, which is returned so the
-- caller settles the same row it opened.
--
-- The dynamic SQL is install_route_bindings' case: every relation is named by a
-- module registration and proved to exist by an ordinary catalog join first,
-- and no value is ever interpolated — only verified relation and column names.
CREATE FUNCTION function_resolution.create_invocation(
    database_id uuid,
    scope text,
    task_identifier text,
    payload jsonb DEFAULT '{}'::jsonb,
    channel text DEFAULT 'sync',
    provenance jsonb DEFAULT '{}'::jsonb,
    route_binding_id uuid DEFAULT NULL,
    entity_id uuid DEFAULT NULL
) RETURNS TABLE (
    id uuid,
    created_at timestamptz,
    started_at timestamptz,
    function_definition_id uuid,
    definition_scope text
) AS $$
DECLARE
    -- The invocations plane this row lands in, and the scope-key column its
    -- registration records (NULL at a global scope).
    invocations_schema text;
    invocations_table text;
    invocations_key text;
    -- One key value for the write: the database itself at database scope, the
    -- owning entity at an entity scope, NULL at a global scope.
    key_value uuid;
    -- The winning definition and where it lives, from the same resolver every
    -- other ingress path uses.
    v_definition_id uuid;
    v_definition_scope text;
    v_definition_database_id uuid;
    definitions_schema text;
    definitions_table text;
    sync_callable boolean;
    -- The definition's own consent to run for a caller with no identity, read
    -- from the same plane as its channels.
    anonymous_callable boolean;
    -- The routes plane serving this scope, and its own recorded ownership key,
    -- for the anonymous route check.
    routes_schema text;
    routes_table text;
    routes_key text;
    route_authorized boolean;
    query text;
BEGIN
    IF create_invocation.database_id IS NULL THEN
        RAISE EXCEPTION 'INVOCATION_DATABASE_REQUIRED: database_id is required'
            USING ERRCODE = 'FR070';
    END IF;

    -- Hard contract, matching enqueue and app_scope: the execution scope is
    -- known at the call site and never silently defaulted.
    IF create_invocation.scope IS NULL THEN
        RAISE EXCEPTION 'INVOCATION_SCOPE_REQUIRED: scope is required (no default scope)'
            USING ERRCODE = 'FR070';
    END IF;

    IF coalesce(create_invocation.task_identifier, '') = '' THEN
        RAISE EXCEPTION 'INVOCATION_TASK_REQUIRED: task_identifier is required'
            USING ERRCODE = 'FR070';
    END IF;

    -- This surface exists for the request lanes that cannot write the table
    -- directly. Every other channel already has a trusted path (the worker's
    -- own role, the api binding's policy arm, the graph/cron triggers), so a
    -- caller naming one here would be claiming a provenance it does not have.
    IF create_invocation.channel IS DISTINCT FROM 'sync' THEN
        RAISE EXCEPTION 'INVOCATION_CHANNEL_UNSUPPORTED: create_invocation opens sync invocations only, got %',
            coalesce(create_invocation.channel, '<null>')
            USING ERRCODE = 'FR070';
    END IF;

    -- 1. The tenant boundary. SECURITY DEFINER means RLS does not hold it, so
    --    it is an explicit check against the session's own database claim
    --    (require_database_id raises when the session established none).
    IF jwt_private.require_database_id() <> create_invocation.database_id THEN
        RAISE EXCEPTION 'INVOCATION_DATABASE_MISMATCH: session is claimed to database % and cannot open an invocation in %',
            jwt_private.require_database_id(), create_invocation.database_id
            USING ERRCODE = 'FR071';
    END IF;

    -- The plane, from the registration for exactly this (database, scope). No
    -- probing of neighbouring scopes: the caller's scope is explicit.
    SELECT s.schema_name, t.name, fim.entity_field
    INTO invocations_schema, invocations_table, invocations_key
    FROM metaschema_modules_public.function_invocation_module AS fim
    JOIN metaschema_public."table" AS t ON t.id = fim.invocations_table_id
    JOIN metaschema_public.schema AS s ON s.id = t.schema_id
    WHERE fim.database_id = create_invocation.database_id
      AND fim.scope = create_invocation.scope;

    IF invocations_schema IS NULL THEN
        RAISE EXCEPTION 'INVOCATION_MODULE_NOT_PROVISIONED: database % has no function_invocation_module at scope "%"',
            create_invocation.database_id, create_invocation.scope
            USING ERRCODE = 'FR072';
    END IF;

    -- The scope key, from the plane's recorded column rather than the scope
    -- name: the scope's own key answers "whose ledger", never "who did it".
    IF invocations_key IS NULL THEN
        key_value := NULL;
    ELSIF invocations_key = 'database_id' THEN
        key_value := create_invocation.database_id;
    ELSE
        IF create_invocation.entity_id IS NULL THEN
            RAISE EXCEPTION 'INVOCATION_ENTITY_REQUIRED: scope "%" is keyed by %, so entity_id is required',
                create_invocation.scope, invocations_key
                USING ERRCODE = 'FR070';
        END IF;
        key_value := create_invocation.entity_id;
    END IF;

    -- 2. The task must resolve, at this (database, scope, entity), to a
    --    definition some frame publishes. A definition-less sync request has
    --    nothing to authorize and nothing to run.
    SELECT r.function_definition_id, r.resolved_scope, r.owner_database_id
    INTO v_definition_id, v_definition_scope, v_definition_database_id
    FROM function_resolution.resolve(
        create_invocation.database_id,
        create_invocation.scope,
        create_invocation.entity_id,
        create_invocation.task_identifier,
        false
    ) AS r;

    IF v_definition_id IS NULL THEN
        RAISE EXCEPTION 'INVOCATION_DEFINITION_NOT_FOUND: no function definition publishes "%" to database % at scope "%"',
            create_invocation.task_identifier, create_invocation.database_id, create_invocation.scope
            USING ERRCODE = 'FR073';
    END IF;

    -- 3. Sync eligibility, read from the definition's OWN home plane — a
    --    platform-declared definition is answered by the platform's
    --    definitions table, the same place discovery found it.
    IF v_definition_database_id IS NULL THEN
        SELECT f.lookup_database_id
        INTO v_definition_database_id
        FROM app_scope.frames(
            create_invocation.database_id,
            create_invocation.scope,
            create_invocation.entity_id
        ) AS f
        WHERE f.scope = v_definition_scope
        LIMIT 1;
    END IF;

    SELECT dl.schema_name, dl.table_name
    INTO definitions_schema, definitions_table
    FROM function_resolution.definitions_location(
        coalesce(v_definition_database_id, create_invocation.database_id),
        v_definition_scope
    ) AS dl;

    IF definitions_schema IS NULL THEN
        RAISE EXCEPTION 'INVOCATION_DEFINITIONS_PLANE_NOT_FOUND: scope "%" of database % has no definitions plane to read channel eligibility from',
            v_definition_scope, coalesce(v_definition_database_id, create_invocation.database_id)
            USING ERRCODE = 'FR072';
    END IF;

    -- Both definition-side facts in one read: the channel it declares, and
    -- whether it consents to run for a caller with no identity.
    query := format(
        'SELECT ''sync'' = ANY(d.access_channels), d.anonymous_callable FROM %I.%I AS d WHERE d.id = $1',
        definitions_schema,
        definitions_table
    );

    -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the definitions plane is named by its own function_module registration
    EXECUTE query INTO sync_callable, anonymous_callable USING v_definition_id;

    IF sync_callable IS NOT TRUE THEN
        RAISE EXCEPTION 'INVOCATION_CHANNEL_NOT_DECLARED: definition % does not declare the sync channel',
            v_definition_id
            USING ERRCODE = 'FR074';
    END IF;

    -- 4. Anonymous authorization. A signed-in caller writing its own ledger row
    --    for a sync-eligible task is authorized by being the session it is; an
    --    anonymous one has no identity to weigh, so two declarations stand in
    --    for it: the definition consents to run without one, and the route it
    --    came through exposes it to the public. Both are proved here, against
    --    the planes, rather than taken from the caller.
    IF jwt_public.current_user_id() IS NULL THEN
        IF anonymous_callable IS NOT TRUE THEN
            RAISE EXCEPTION 'INVOCATION_ANONYMOUS_NOT_CALLABLE: definition % does not declare anonymous_callable, so "%" cannot run without an identity',
                v_definition_id, create_invocation.task_identifier
                USING ERRCODE = 'FR075';
        END IF;

        IF create_invocation.route_binding_id IS NULL THEN
            RAISE EXCEPTION 'INVOCATION_ANONYMOUS_ROUTE_REQUIRED: an anonymous invocation must name the route binding it arrived through'
                USING ERRCODE = 'FR075';
        END IF;

        SELECT r.routes_schema, r.routes_table
        INTO routes_schema, routes_table
        FROM app_scope.routing_tables(create_invocation.database_id, create_invocation.scope) AS r;

        IF routes_schema IS NULL OR routes_table IS NULL THEN
            RAISE EXCEPTION 'INVOCATION_ROUTES_PLANE_NOT_FOUND: scope "%" has no routes plane on any frame of database %, so no route can authorize an anonymous invocation',
                create_invocation.scope, create_invocation.database_id
                USING ERRCODE = 'FR072';
        END IF;

        SELECT rm.entity_field
        INTO routes_key
        FROM metaschema_modules_public.route_module AS rm
        JOIN metaschema_public."table" AS t ON t.id = rm.routes_table_id
        JOIN metaschema_public.schema AS s ON s.id = t.schema_id
        WHERE s.schema_name = routes_schema
          AND t.name = routes_table;

        query := format(
            'SELECT EXISTS (SELECT 1 FROM %I.%I AS r'
            || ' WHERE r.id = $1 AND r.target_function_id = $2 AND r.is_active'
            || ' AND r.anonymous%s)',
            routes_schema,
            routes_table,
            CASE WHEN routes_key IS NULL
                 THEN ' AND $3 IS NULL'
                 ELSE format(' AND r.%I = $3', routes_key)
            END
        );

        -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the routes plane is named by app_scope.routing_tables
        EXECUTE query
        INTO route_authorized
        USING create_invocation.route_binding_id, v_definition_id, key_value;

        IF NOT route_authorized THEN
            RAISE EXCEPTION 'INVOCATION_ANONYMOUS_NOT_AUTHORIZED: route % of %.% does not expose "%" anonymously',
                create_invocation.route_binding_id, routes_schema, routes_table, create_invocation.task_identifier
                USING ERRCODE = 'FR075';
        END IF;
    END IF;

    -- The write. Every invocations plane carries database_id — the scope key at
    -- database scope, attribution elsewhere — so it is stamped either way, and
    -- the scope-key column is added only when the plane records one.
    --
    -- created_at is truncated to milliseconds because it is half of the row's
    -- identity pair (created_at, id): the caller settles the row by that pair,
    -- and a microsecond that no JS timestamp can carry makes the settle address
    -- a row that does not exist. The worker's own insert path stamps the same
    -- millisecond precision.
    query := format(
        'INSERT INTO %I.%I AS i (task_identifier, payload, channel, provenance, status, created_at, started_at, database_id%s)'
        || ' VALUES ($1, $2, $3, $4, ''running'','
        || ' date_trunc(''milliseconds'', now()), date_trunc(''milliseconds'', now()), $5%s)'
        || ' RETURNING i.id, i.created_at, i.started_at, i.function_definition_id, i.definition_scope',
        invocations_schema,
        invocations_table,
        CASE WHEN invocations_key IS NULL OR invocations_key = 'database_id'
             THEN ''
             ELSE format(', %I', invocations_key)
        END,
        CASE WHEN invocations_key IS NULL OR invocations_key = 'database_id'
             THEN ''
             ELSE ', $6'
        END
    );

    IF invocations_key IS NULL OR invocations_key = 'database_id' THEN
        -- pgsql-lint-disable-next-line no-dynamic-sql -- write: the invocations plane is named by its own function_invocation_module registration; every value is bound
        RETURN QUERY EXECUTE query
        USING create_invocation.task_identifier,
              coalesce(create_invocation.payload, '{}'::jsonb),
              create_invocation.channel,
              coalesce(create_invocation.provenance, '{}'::jsonb),
              create_invocation.database_id;
    ELSE
        -- pgsql-lint-disable-next-line no-dynamic-sql -- write: the invocations plane is named by its own function_invocation_module registration; every value is bound
        RETURN QUERY EXECUTE query
        USING create_invocation.task_identifier,
              coalesce(create_invocation.payload, '{}'::jsonb),
              create_invocation.channel,
              coalesce(create_invocation.provenance, '{}'::jsonb),
              create_invocation.database_id,
              key_value;
    END IF;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION function_resolution.create_invocation(uuid, text, text, jsonb, text, jsonb, uuid, uuid) IS
'Open one running sync invocation row in the addressed database''s own invocations plane, under the caller''s request role. Proves the session''s database claim, that the task resolves to a definition declaring the sync channel, and — for an anonymous caller — that the definition declares anonymous_callable and that the named route binding is active, targets that definition and declares anonymous access. Attribution and the (function_definition_id, definition_scope) pair are stamped by the plane''s own BEFORE INSERT trigger from the transaction claims.';

COMMIT;
