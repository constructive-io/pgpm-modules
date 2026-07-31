\echo Use "CREATE EXTENSION pgpm-function-resolution" to load this file. \quit
CREATE SCHEMA IF NOT EXISTS function_resolution;

GRANT USAGE ON SCHEMA function_resolution TO administrator;

GRANT USAGE ON SCHEMA function_resolution TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA function_resolution
  GRANT EXECUTE ON FUNCTIONS TO administrator;

CREATE FUNCTION function_resolution.definitions_location(
  database_id uuid,
  scope text
) RETURNS TABLE (
  schema_name text,
  table_name text,
  entity_field text
) AS $EOFCODE$
DECLARE
    v_defs_table_id uuid;
    v_entity_field text;
BEGIN
    SELECT fm.definitions_table_id, fm.entity_field
    INTO v_defs_table_id, v_entity_field
    FROM metaschema_modules_public.function_module fm
    WHERE fm.database_id = definitions_location.database_id
      AND fm.scope = definitions_location.scope;

    IF NOT FOUND OR v_defs_table_id IS NULL THEN
        RETURN;
    END IF;

    SELECT s.schema_name, t.name
    INTO definitions_location.schema_name, definitions_location.table_name
    FROM metaschema_public.schema s
    JOIN metaschema_public."table" t ON (t.schema_id = s.id AND t.database_id = s.database_id)
    WHERE t.id = v_defs_table_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    definitions_location.entity_field := v_entity_field;
    RETURN NEXT;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.routing(
  database_id uuid,
  scope text,
  function_definition_id uuid
) RETURNS TABLE (
  queue_name text,
  priority int,
  max_attempts int
) AS $EOFCODE$
DECLARE
    v_schema text;
    v_table text;
    v_entity_field text;
    v_query text;
BEGIN
    SELECT l.schema_name, l.table_name, l.entity_field
    INTO v_schema, v_table, v_entity_field
    FROM function_resolution.definitions_location(routing.database_id, routing.scope) l;

    IF v_schema IS NULL OR function_definition_id IS NULL THEN
        RETURN;
    END IF;

    -- SELECT queue_name, priority, max_attempts FROM "<schema>"."<table>" WHERE id = $1
    v_query := format(
        'SELECT queue_name, priority, max_attempts FROM %I.%I WHERE id = $1',
        v_schema, v_table
    );

    EXECUTE v_query
        INTO routing.queue_name,
             routing.priority,
             routing.max_attempts
        USING function_definition_id;

    -- Only surface a routing row when the definition actually exists (a missing
    -- id leaves every column NULL — the caller wants defaults, not a NULL row).
    IF routing.queue_name IS NULL
       AND routing.priority IS NULL
       AND routing.max_attempts IS NULL THEN
        RETURN;
    END IF;

    RETURN NEXT;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.catalog_location(
  database_id uuid
) RETURNS TABLE (
  schema_name text,
  table_name text
) AS $EOFCODE$
DECLARE
    v_functions_table_id uuid;
BEGIN
    BEGIN
        SELECT cm.functions_table_id
        INTO STRICT v_functions_table_id
        FROM metaschema_modules_public.catalog_module cm
        WHERE cm.database_id = catalog_location.database_id
          AND cm.functions_table_id <> uuid_nil();
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN;
        WHEN TOO_MANY_ROWS THEN
            RAISE EXCEPTION 'FUNCTION_RESOLUTION_CATALOG_AMBIGUOUS: multiple functions catalogs registered for database %',
                catalog_location.database_id;
    END;

    SELECT s.schema_name, t.name
    INTO catalog_location.schema_name, catalog_location.table_name
    FROM metaschema_public.schema s
    JOIN metaschema_public."table" t ON (t.schema_id = s.id AND t.database_id = s.database_id)
    WHERE t.id = v_functions_table_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    RETURN NEXT;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.resolve(
  database_id uuid,
  scope text,
  entity_id uuid,
  task_identifier text,
  require_definition boolean DEFAULT true
) RETURNS TABLE (
  function_definition_id uuid,
  resolved_scope text,
  owner_database_id uuid
) AS $EOFCODE$
DECLARE
    v_frame_db record;
    v_schema text;
    v_table text;
    v_query text;
    v_hit record;
    v_best_ord bigint;
BEGIN
    -- Group the ordered frames by lookup database, expanding each frame into
    -- its probe candidates (exact key first, scope-default second) with a
    -- global ordinality that preserves frame precedence across databases.
    FOR v_frame_db IN
        SELECT c.lookup_database_id,
               array_agg(c.owner_scope ORDER BY c.ord) AS scopes,
               array_agg(c.owner_key ORDER BY c.ord) AS keys,
               array_agg(c.ord ORDER BY c.ord) AS ords
        FROM (
            SELECT f.lookup_database_id,
                   f.scope AS owner_scope,
                   cand.owner_key,
                   (f.ord * 2) + cand.off AS ord
            FROM app_scope.frames(
                resolve.database_id,
                resolve.scope,
                resolve.entity_id
            ) WITH ORDINALITY AS f(scope, lookup_database_id, key_value, ord)
            CROSS JOIN LATERAL (
                VALUES (f.key_value, 0::bigint), (NULL::uuid, 1::bigint)
            ) AS cand(owner_key, off)
            -- Global frames carry no key: emit the NULL candidate once.
            WHERE cand.off = 0 OR f.key_value IS NOT NULL
        ) c
        GROUP BY c.lookup_database_id
        ORDER BY min(c.ord)
    LOOP
        SELECT l.schema_name, l.table_name
        INTO v_schema, v_table
        FROM function_resolution.catalog_location(v_frame_db.lookup_database_id) l;

        IF v_schema IS NULL THEN
            -- No catalog for this frame database. If it hosts function
            -- modules the catalog cannot answer for it — fail loud so a
            -- missing catalog never silently mis-resolves as "not found".
            IF EXISTS (
                SELECT 1 FROM metaschema_modules_public.function_module fm
                WHERE fm.database_id = v_frame_db.lookup_database_id
            ) THEN
                RAISE EXCEPTION USING
                    errcode = 'FR001',
                    message = format(
                        'FUNCTION_RESOLUTION_CATALOG_UNAVAILABLE: database %s hosts function modules but has no functions catalog',
                        v_frame_db.lookup_database_id
                    );
            END IF;
            CONTINUE;
        END IF;

        -- One indexed read per catalog: LATERAL over the ordered candidates,
        -- each branch an exact probe of one partial unique index.
        v_query := format(
            'SELECT hit.id, hit.owner_scope, hit.database_id, cand.ord
             FROM unnest($2::text[], $3::uuid[], $4::bigint[]) AS cand(owner_scope, owner_key, ord)
             CROSS JOIN LATERAL (
                 SELECT c.id, c.owner_scope, c.database_id
                 FROM %I.%I c
                 WHERE c.task_identifier = $1
                   AND c.owner_scope = cand.owner_scope
                   AND c.owner_key = cand.owner_key
                   AND cand.owner_key IS NOT NULL
                 UNION ALL
                 SELECT c.id, c.owner_scope, c.database_id
                 FROM %I.%I c
                 WHERE c.task_identifier = $1
                   AND c.owner_scope = cand.owner_scope
                   AND c.owner_key IS NULL
                   AND cand.owner_key IS NULL
             ) hit
             ORDER BY cand.ord
             LIMIT 1',
            v_schema, v_table, v_schema, v_table
        );

        EXECUTE v_query
        INTO v_hit
        USING resolve.task_identifier,
              v_frame_db.scopes, v_frame_db.keys, v_frame_db.ords;

        IF v_hit.id IS NOT NULL AND (v_best_ord IS NULL OR v_hit.ord < v_best_ord) THEN
            v_best_ord := v_hit.ord;
            resolve.function_definition_id := v_hit.id;
            resolve.resolved_scope := v_hit.owner_scope;
            resolve.owner_database_id := v_hit.database_id;
        END IF;
    END LOOP;

    IF resolve.function_definition_id IS NOT NULL THEN
        RETURN NEXT;
        RETURN;
    END IF;

    -- Chain exhausted.
    IF require_definition THEN
        RAISE EXCEPTION 'FUNCTION_DEFINITION_NOT_FOUND: no definition for task_identifier "%" in the scope chain starting at scope "%" (database_id=%)',
            task_identifier, scope, database_id;
    END IF;

    RETURN;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.resolve_invocation(
  database_id uuid,
  scope text,
  entity_id uuid,
  task_identifier text,
  existing_id uuid DEFAULT NULL,
  existing_scope text DEFAULT NULL,
  api_binding_id uuid DEFAULT NULL
) RETURNS TABLE (
  function_definition_id uuid,
  definition_scope text
) AS $EOFCODE$
DECLARE
    v_scope text;
    v_lookup_db uuid;
    v_probe_key uuid;
    v_found uuid;
    v_catalog_schema text;
    v_catalog_table text;
BEGIN
    -- API-provenance path (api_binding_id present) must declare its definition
    -- explicitly — the function_callable_check policy verifies the binding
    -- against the supplied function_definition_id. Never auto-resolve one for
    -- it: a NULL id stays NULL so the policy can deny.
    IF existing_id IS NULL AND api_binding_id IS NOT NULL THEN
        resolve_invocation.function_definition_id := NULL;
        resolve_invocation.definition_scope := NULL;
        RETURN NEXT;
        RETURN;
    END IF;

    IF existing_id IS NOT NULL THEN
        v_scope := COALESCE(resolve_invocation.existing_scope, resolve_invocation.scope);

        -- Key/lookup database for the declared scope come from the same frame
        -- definition resolution uses, so an `org` pair keys by the owning org
        -- and the platform frame probes the platform database.
        SELECT f.lookup_database_id, f.key_value
        INTO v_lookup_db, v_probe_key
        FROM app_scope.frames(resolve_invocation.database_id, resolve_invocation.scope, resolve_invocation.entity_id) f
        WHERE f.scope = v_scope;

        IF v_lookup_db IS NULL THEN
            v_lookup_db := database_id;
        END IF;

        SELECT l.schema_name, l.table_name
        INTO v_catalog_schema, v_catalog_table
        FROM function_resolution.catalog_location(v_lookup_db) l;

        IF v_catalog_schema IS NULL THEN
            RAISE EXCEPTION 'FUNCTION_RESOLUTION_CATALOG_UNAVAILABLE: database % has no functions catalog to validate pair against (task_identifier "%")',
                v_lookup_db, task_identifier
                USING ERRCODE = 'FR001';
        END IF;

        -- Same two-pass keying as resolution: the exact scope-key row wins,
        -- the scope-default (owner_key IS NULL) row only as fallback.
        EXECUTE format(
            'SELECT id FROM %I.%I WHERE owner_scope = $1 AND task_identifier = $2 AND owner_key = $3',
            v_catalog_schema, v_catalog_table
        ) INTO v_found USING v_scope, task_identifier, v_probe_key;
        IF v_found IS NULL THEN
            EXECUTE format(
                'SELECT id FROM %I.%I WHERE owner_scope = $1 AND task_identifier = $2 AND owner_key IS NULL',
                v_catalog_schema, v_catalog_table
            ) INTO v_found USING v_scope, task_identifier;
        END IF;

        IF v_found IS DISTINCT FROM existing_id THEN
            RAISE EXCEPTION 'FUNCTION_DEFINITION_INVALID_PAIR: function_definition_id % / definition_scope "%" does not resolve to task_identifier "%" (database_id=%)',
                existing_id, v_scope, task_identifier, database_id;
        END IF;

        resolve_invocation.function_definition_id := existing_id;
        resolve_invocation.definition_scope := v_scope;
        RETURN NEXT;
        RETURN;
    END IF;

    -- No pair supplied: resolve across the scope chain. Definition-less stays
    -- allowed, so a miss leaves both columns NULL rather than raising.
    SELECT r.function_definition_id, r.resolved_scope
    INTO resolve_invocation.function_definition_id, resolve_invocation.definition_scope
    FROM function_resolution.resolve(
        resolve_invocation.database_id, resolve_invocation.scope, resolve_invocation.entity_id, resolve_invocation.task_identifier, false
    ) r;

    RETURN NEXT;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE FUNCTION function_resolution.enqueue(
  task_identifier text,
  payload pg_catalog.json DEFAULT '{}'::json,
  scope text DEFAULT NULL,
  entity_id uuid DEFAULT NULL,
  function_definition_id uuid DEFAULT NULL,
  definition_scope text DEFAULT NULL,
  job_key text DEFAULT NULL,
  queue_name text DEFAULT NULL,
  run_at timestamptz DEFAULT now(),
  max_attempts int DEFAULT NULL,
  priority int DEFAULT NULL,
  organization_id uuid DEFAULT NULL,
  entity_type text DEFAULT NULL,
  should_resolve boolean DEFAULT true,
  resolution_scope text DEFAULT NULL,
  resolution_key uuid DEFAULT NULL,
  db_id uuid DEFAULT jwt_private.current_database_id()
) RETURNS app_jobs.jobs AS $EOFCODE$
DECLARE
    v_database_id uuid;
    v_exec_scope text;
    v_resolution_scope text;
    v_resolution_key uuid;
    v_fn_id uuid;
    v_def_scope text;
    v_defs_db uuid;
    v_queue_name text;
    v_priority integer;
    v_max_attempts integer;
BEGIN
    v_database_id := db_id;

    -- Hard contract: the execution scope is a provisioning-time constant at the
    -- call site, never silently defaulted (constructive-planning #1183).
    IF scope IS NULL THEN
        RAISE EXCEPTION 'ENQUEUE_SCOPE_REQUIRED: scope is required (no default scope)';
    END IF;
    v_exec_scope := scope;

    -- The resolution walk starts from a scope-key SEPARATE from the billing
    -- entity_id. It defaults to the execution scope/entity so the invocation lane
    -- (which supplies a stamped pair and never resolves here) is unchanged.
    v_resolution_scope := COALESCE(resolution_scope, scope);
    v_resolution_key := COALESCE(resolution_key, entity_id);

    v_fn_id := function_definition_id;
    v_def_scope := definition_scope;

    -- Resolve the winning definition when the caller did not already stamp one.
    -- resolve() also returns the definition's home database, so the resolving
    -- lane needs no second frame walk below.
    IF v_fn_id IS NULL AND should_resolve THEN
        SELECT r.function_definition_id, r.resolved_scope, r.owner_database_id
        INTO v_fn_id, v_def_scope, v_defs_db
        FROM function_resolution.resolve(
            v_database_id, v_resolution_scope, v_resolution_key, task_identifier, false
        ) r;
    END IF;

    -- Definition routing: read queue_name/priority/max_attempts from the exact
    -- winning definition (no scope-chain re-walk). The definition's home database
    -- is the frame's lookup_database_id for its scope (the platform database for a
    -- platform-scope definition, the execution database otherwise); only the
    -- caller-supplied-pair lane still derives it from the declared scope's frame.
    IF v_fn_id IS NOT NULL AND v_def_scope IS NOT NULL THEN
        IF v_defs_db IS NULL THEN
            SELECT f.lookup_database_id
            INTO v_defs_db
            FROM app_scope.frames(v_database_id, v_resolution_scope, v_resolution_key) f
            WHERE f.scope = v_def_scope
            LIMIT 1;
        END IF;

        IF v_defs_db IS NULL THEN
            v_defs_db := v_database_id;
        END IF;

        SELECT rt.queue_name, rt.priority, rt.max_attempts
        INTO v_queue_name, v_priority, v_max_attempts
        FROM function_resolution.routing(v_defs_db, v_def_scope, v_fn_id) rt;
    END IF;

    -- Caller-supplied routing always wins over the definition's; the definition's
    -- wins over the add_job hard defaults.
    RETURN app_jobs.add_job(
        identifier := task_identifier,
        payload := COALESCE(payload, '{}'::json),
        job_key := job_key,
        queue_name := COALESCE(queue_name, v_queue_name),
        run_at := COALESCE(run_at, now()),
        max_attempts := COALESCE(max_attempts, v_max_attempts, 25),
        priority := COALESCE(priority, v_priority, 0),
        entity_id := entity_id,
        organization_id := organization_id,
        entity_type := entity_type,
        function_definition_id := v_fn_id,
        definition_scope := v_def_scope,
        db_id := v_database_id
    );
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION function_resolution.enqueue(text, pg_catalog.json, text, uuid, uuid, text, text, text, timestamptz, int, int, uuid, text, boolean, text, uuid, uuid) IS 'Resolver-aware job enqueue: resolves (or trusts a supplied) function definition for the execution (database, scope, entity, task_identifier), stamps the (function_definition_id, definition_scope) pair and the definition''s queue routing, then delegates the insert to app_jobs.add_job. The single enqueue path for function jobs; definition-less tasks enqueue with a NULL pair. Portable: built only on app_scope + the metaschema catalog + app_jobs, no AST/deparser runtime.';