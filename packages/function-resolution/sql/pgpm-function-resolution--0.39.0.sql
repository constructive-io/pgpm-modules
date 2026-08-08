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
  function_definition_id uuid
) RETURNS TABLE (
  queue_name text,
  priority int,
  max_attempts int
) AS $EOFCODE$
BEGIN
    IF function_definition_id IS NULL THEN
        RETURN;
    END IF;

    SELECT c.queue_name, c.priority, c.max_attempts
    INTO routing.queue_name,
         routing.priority,
         routing.max_attempts
    FROM catalog_private.functions c
    WHERE c.id = routing.function_definition_id
      AND c.database_id = routing.database_id;

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
    v_unanswerable uuid;
    v_hit record;
BEGIN
    -- A frame database that hosts function modules but never deployed a catalog
    -- module has definitions the catalog cannot see. Answering "not found" there
    -- would be a wrong answer, so it is raised before any probe.
    SELECT f.lookup_database_id
    INTO v_unanswerable
    FROM app_scope.frames(
        resolve.database_id,
        resolve.scope,
        resolve.entity_id
    ) AS f(scope, lookup_database_id, key_value)
    WHERE EXISTS (
        SELECT 1 FROM metaschema_modules_public.function_module fm
        WHERE fm.database_id = f.lookup_database_id
    )
    AND NOT EXISTS (
        SELECT 1
        FROM metaschema_modules_public.catalog_module cm
        WHERE cm.database_id = f.lookup_database_id
          AND cm.functions_table_id IS NOT NULL
          AND cm.functions_table_id <> uuid_nil()
    )
    LIMIT 1;

    IF v_unanswerable IS NOT NULL THEN
        RAISE EXCEPTION USING
            errcode = 'FR001',
            message = format(
                'FUNCTION_RESOLUTION_CATALOG_UNAVAILABLE: database %s hosts function modules but has no functions catalog',
                v_unanswerable
            );
    END IF;

    -- One indexed read: LATERAL over the ordered candidates, each branch an
    -- exact probe of one partial unique index.
    SELECT hit.id, hit.owner_scope, hit.database_id
    INTO v_hit
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
    ) cand
    CROSS JOIN LATERAL (
        SELECT c.id, c.owner_scope, c.database_id
        FROM catalog_private.functions c
        WHERE c.task_identifier = resolve.task_identifier
          AND c.owner_scope = cand.owner_scope
          AND c.owner_key = cand.owner_key
          AND cand.owner_key IS NOT NULL
          AND c.database_id = CASE
                WHEN cand.owner_scope = 'database' THEN cand.owner_key
                ELSE cand.lookup_database_id
              END
        UNION ALL
        SELECT c.id, c.owner_scope, c.database_id
        FROM catalog_private.functions c
        WHERE c.task_identifier = resolve.task_identifier
          AND c.owner_scope = cand.owner_scope
          AND c.owner_key IS NULL
          AND cand.owner_key IS NULL
          AND c.database_id = cand.lookup_database_id
    ) hit
    ORDER BY cand.ord
    LIMIT 1;

    IF v_hit.id IS NOT NULL THEN
        resolve.function_definition_id := v_hit.id;
        resolve.resolved_scope := v_hit.owner_scope;
        resolve.owner_database_id := v_hit.database_id;
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
    v_expected_db uuid;
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

        IF NOT EXISTS (
            SELECT 1
            FROM metaschema_modules_public.catalog_module cm
            WHERE cm.database_id = v_lookup_db
              AND cm.functions_table_id IS NOT NULL
              AND cm.functions_table_id <> uuid_nil()
        ) THEN
            RAISE EXCEPTION 'FUNCTION_RESOLUTION_CATALOG_UNAVAILABLE: database % has no functions catalog to validate pair against (task_identifier "%")',
                v_lookup_db, task_identifier
                USING ERRCODE = 'FR001';
        END IF;

        -- Same two-pass keying as resolution: the exact scope-key row wins, the
        -- scope-default (owner_key IS NULL) row only as fallback. Both carry the
        -- shared plane's row-identity predicate.
        v_expected_db := CASE
            WHEN v_scope = 'database' AND v_probe_key IS NOT NULL THEN v_probe_key
            ELSE v_lookup_db
        END;

        SELECT c.id
        INTO v_found
        FROM catalog_private.functions c
        WHERE c.owner_scope = v_scope
          AND c.task_identifier = resolve_invocation.task_identifier
          AND c.owner_key = v_probe_key
          AND c.database_id = v_expected_db;

        IF v_found IS NULL THEN
            SELECT c.id
            INTO v_found
            FROM catalog_private.functions c
            WHERE c.owner_scope = v_scope
              AND c.task_identifier = resolve_invocation.task_identifier
              AND c.owner_key IS NULL
              AND c.database_id = v_lookup_db;
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
        FROM function_resolution.routing(v_defs_db, v_fn_id) rt;
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

CREATE FUNCTION function_resolution.frame_candidates(
  database_id uuid,
  scope text,
  entity_id uuid DEFAULT NULL
) RETURNS TABLE (
  lookup_database_id uuid,
  owner_scope text,
  owner_key uuid,
  ord bigint
) AS $EOFCODE$
BEGIN
    RETURN QUERY
    SELECT f.lookup_database_id,
           f.scope,
           cand.owner_key,
           (f.ord * 2) + cand.off
    FROM app_scope.frames(
        frame_candidates.database_id,
        frame_candidates.scope,
        frame_candidates.entity_id
    ) WITH ORDINALITY AS f(scope, lookup_database_id, key_value, ord)
    CROSS JOIN LATERAL (
        VALUES (f.key_value, 0::bigint), (NULL::uuid, 1::bigint)
    ) AS cand(owner_key, off)
    -- Global frames carry no key: emit the NULL candidate once.
    WHERE cand.off = 0 OR f.key_value IS NOT NULL
    ORDER BY (f.ord * 2) + cand.off;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.bucket_matches(
  database_id uuid,
  scope text,
  entity_id uuid,
  tags text[],
  type_filter text DEFAULT NULL
) RETURNS TABLE (
  bucket_id uuid,
  bucket_key text,
  bucket_type text,
  physical_name text,
  owner_database_id uuid,
  owner_scope text,
  owner_key uuid
) AS $EOFCODE$
BEGIN
    RETURN QUERY
    WITH hits AS (
        SELECT b.id,
               b.key,
               b.type,
               b.physical_name,
               b.database_id,
               b.owner_scope,
               b.owner_key,
               cand.ord
        FROM function_resolution.frame_candidates(
            bucket_matches.database_id,
            bucket_matches.scope,
            bucket_matches.entity_id
        ) cand
        JOIN catalog_private.buckets b
          ON b.owner_scope = cand.owner_scope
         AND b.owner_key IS NOT DISTINCT FROM cand.owner_key
         AND b.database_id = CASE
               WHEN cand.owner_scope = 'database' THEN cand.owner_key
               ELSE cand.lookup_database_id
             END
        WHERE b.tags @> bucket_matches.tags
          AND (bucket_matches.type_filter IS NULL OR b.type = bucket_matches.type_filter)
          AND (b.database_id = bucket_matches.database_id OR b.is_visible)
    )
    SELECT h.id,
           h.key,
           h.type,
           h.physical_name,
           h.database_id,
           h.owner_scope,
           h.owner_key
    FROM hits h
    WHERE h.ord = (SELECT min(hh.ord) FROM hits hh)
    ORDER BY h.id;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.resolve_bucket(
  database_id uuid,
  scope text,
  entity_id uuid,
  tags text[],
  type_filter text DEFAULT NULL
) RETURNS TABLE (
  bucket_id uuid,
  bucket_key text,
  bucket_type text,
  physical_name text,
  owner_database_id uuid,
  owner_scope text,
  owner_key uuid
) AS $EOFCODE$
DECLARE
    v_matches jsonb;
    v_match jsonb;
BEGIN
    IF resolve_bucket.tags IS NULL OR cardinality(resolve_bucket.tags) = 0 THEN
        RAISE EXCEPTION 'CAPABILITY_BUCKET_SELECTOR_EMPTY: a bucket selector needs at least one tag (database_id=%, scope="%")',
            resolve_bucket.database_id, resolve_bucket.scope
            USING ERRCODE = 'FR010';
    END IF;

    -- Every frame in one indexed read, keeping only the matches of the most
    -- specific frame that answered: a nearer frame outranks an outer one, and
    -- ties within that frame are the ambiguity raised below.
    SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m.bucket_id), '[]'::jsonb)
    INTO v_matches
    FROM function_resolution.bucket_matches(
        resolve_bucket.database_id,
        resolve_bucket.scope,
        resolve_bucket.entity_id,
        resolve_bucket.tags,
        resolve_bucket.type_filter
    ) m;

    IF jsonb_array_length(v_matches) = 0 THEN
        RAISE EXCEPTION 'CAPABILITY_BUCKET_NOT_FOUND: no bucket tagged % % resolves in the scope chain starting at scope "%" (database_id=%)',
            resolve_bucket.tags,
            COALESCE('of type ' || resolve_bucket.type_filter, '(any type)'),
            resolve_bucket.scope,
            resolve_bucket.database_id
            USING ERRCODE = 'FR011';
    END IF;

    IF jsonb_array_length(v_matches) > 1 THEN
        RAISE EXCEPTION 'CAPABILITY_BUCKET_AMBIGUOUS: % buckets tagged % % resolve equally (candidates: %); retag, narrow by type, or bind the capability explicitly',
            jsonb_array_length(v_matches),
            resolve_bucket.tags,
            COALESCE('of type ' || resolve_bucket.type_filter, '(any type)'),
            (SELECT string_agg(format('%s (%s)', m->>'bucket_key', m->>'bucket_id'), ', ' ORDER BY m->>'bucket_key')
               FROM jsonb_array_elements(v_matches) m)
            USING ERRCODE = 'FR012';
    END IF;

    v_match := v_matches->0;

    resolve_bucket.bucket_id := (v_match->>'bucket_id')::uuid;
    resolve_bucket.bucket_key := v_match->>'bucket_key';
    resolve_bucket.bucket_type := v_match->>'bucket_type';
    resolve_bucket.physical_name := v_match->>'physical_name';
    resolve_bucket.owner_database_id := (v_match->>'owner_database_id')::uuid;
    resolve_bucket.owner_scope := v_match->>'owner_scope';
    resolve_bucket.owner_key := (v_match->>'owner_key')::uuid;

    RETURN NEXT;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.default_bucket_tag(
  public_access boolean
) RETURNS text AS $EOFCODE$
    SELECT CASE WHEN default_bucket_tag.public_access THEN 'default-public' ELSE 'default' END;
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION function_resolution.resolve_default_bucket(
  database_id uuid,
  scope text,
  entity_id uuid,
  public_access boolean,
  bucket_key text DEFAULT NULL
) RETURNS TABLE (
  bucket_id uuid,
  resolved_key text,
  bucket_type text,
  physical_name text,
  owner_database_id uuid,
  owner_scope text,
  owner_key uuid
) AS $EOFCODE$
DECLARE
    v_tag text;
    v_matches jsonb;
    v_match jsonb;
BEGIN
    -- A blank override is a caller bug, not a request for the default: falling
    -- through to tag resolution would turn a broken field binding into a
    -- silently different bucket.
    IF resolve_default_bucket.bucket_key IS NOT NULL
       AND btrim(resolve_default_bucket.bucket_key) = '' THEN
        PERFORM errors.raise_error(
            'STORAGE_BUCKET_KEY_BLANK',
            jsonb_build_object(
                'database_id', resolve_default_bucket.database_id,
                'scope', resolve_default_bucket.scope
            ),
            'internal'
        );
    END IF;

    v_tag := COALESCE(
        resolve_default_bucket.bucket_key,
        function_resolution.default_bucket_tag(resolve_default_bucket.public_access)
    );

    SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m.bucket_id), '[]'::jsonb)
    INTO v_matches
    FROM function_resolution.bucket_matches(
        resolve_default_bucket.database_id,
        resolve_default_bucket.scope,
        resolve_default_bucket.entity_id,
        ARRAY[v_tag]
    ) m;

    IF jsonb_array_length(v_matches) = 0 THEN
        PERFORM errors.raise_error(
            'STORAGE_DEFAULT_BUCKET_NOT_FOUND',
            jsonb_build_object(
                'database_id', resolve_default_bucket.database_id,
                'scope', resolve_default_bucket.scope,
                'entity_id', resolve_default_bucket.entity_id,
                'tag', v_tag,
                'explicit_key', resolve_default_bucket.bucket_key IS NOT NULL
            ),
            'internal'
        );
    END IF;

    IF jsonb_array_length(v_matches) > 1 THEN
        PERFORM errors.raise_error(
            'STORAGE_DEFAULT_BUCKET_AMBIGUOUS',
            jsonb_build_object(
                'database_id', resolve_default_bucket.database_id,
                'scope', resolve_default_bucket.scope,
                'entity_id', resolve_default_bucket.entity_id,
                'tag', v_tag,
                'explicit_key', resolve_default_bucket.bucket_key IS NOT NULL,
                'candidates', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'bucket_id', c->>'bucket_id',
                        'key', c->>'bucket_key',
                        'type', c->>'bucket_type'
                    ) ORDER BY c->>'bucket_key')
                    FROM jsonb_array_elements(v_matches) c
                )
            ),
            'internal'
        );
    END IF;

    v_match := v_matches->0;

    resolve_default_bucket.bucket_id := (v_match->>'bucket_id')::uuid;
    resolve_default_bucket.resolved_key := v_match->>'bucket_key';
    resolve_default_bucket.bucket_type := v_match->>'bucket_type';
    resolve_default_bucket.physical_name := v_match->>'physical_name';
    resolve_default_bucket.owner_database_id := (v_match->>'owner_database_id')::uuid;
    resolve_default_bucket.owner_scope := v_match->>'owner_scope';
    resolve_default_bucket.owner_key := (v_match->>'owner_key')::uuid;

    RETURN NEXT;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.bucket_catalog_row(
  database_id uuid,
  scope text,
  entity_id uuid,
  bucket_id uuid
) RETURNS TABLE (
  bucket_key text,
  bucket_type text,
  physical_name text,
  owner_database_id uuid,
  owner_scope text,
  owner_key uuid
) AS $EOFCODE$
BEGIN
    RETURN QUERY
    SELECT b.key,
           b.type,
           b.physical_name,
           b.database_id,
           b.owner_scope,
           b.owner_key
    FROM function_resolution.frame_candidates(
        bucket_catalog_row.database_id,
        bucket_catalog_row.scope,
        bucket_catalog_row.entity_id
    ) cand
    JOIN catalog_private.buckets b
      ON b.owner_scope = cand.owner_scope
     AND b.owner_key IS NOT DISTINCT FROM cand.owner_key
     AND b.database_id = CASE
           WHEN cand.owner_scope = 'database' THEN cand.owner_key
           ELSE cand.lookup_database_id
         END
    WHERE b.id = bucket_catalog_row.bucket_id
      AND (b.database_id = bucket_catalog_row.database_id OR b.is_visible)
    ORDER BY cand.ord
    LIMIT 1;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.api_catalog_row(
  database_id uuid,
  scope text,
  entity_id uuid,
  api_id uuid
) RETURNS TABLE (
  api_name text,
  owner_database_id uuid,
  owner_scope text,
  owner_key uuid
) AS $EOFCODE$
BEGIN
    RETURN QUERY
    SELECT a.name,
           a.database_id,
           a.owner_scope,
           a.owner_key
    FROM function_resolution.frame_candidates(
        api_catalog_row.database_id,
        api_catalog_row.scope,
        api_catalog_row.entity_id
    ) cand
    JOIN catalog_private.apis a
      ON a.owner_scope = cand.owner_scope
     AND a.owner_key IS NOT DISTINCT FROM cand.owner_key
     AND a.database_id = CASE
           WHEN cand.owner_scope = 'database' THEN cand.owner_key
           ELSE cand.lookup_database_id
         END
    WHERE a.id = api_catalog_row.api_id
      AND (a.database_id = api_catalog_row.database_id OR a.is_visible)
    ORDER BY cand.ord
    LIMIT 1;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.resolve_api(
  database_id uuid,
  scope text,
  entity_id uuid,
  selector text
) RETURNS TABLE (
  api_id uuid,
  api_name text,
  owner_database_id uuid,
  owner_scope text,
  owner_key uuid
) AS $EOFCODE$
DECLARE
    v_kind text;
    v_ref text;
    v_api_filter text;
    v_scope_filter text;
    v_module_table text;
    v_module_relid oid;
    v_frame record;
    v_query text;
    v_row record;
    v_matches jsonb := '[]'::jsonb;
    v_match jsonb;
    v_module_schema_id uuid;
    v_module_api_name text;
    v_module_has_scope boolean;
    v_apis_schema text;
    v_apis_table text;
    v_api_schemas_schema text;
    v_api_schemas_table text;
    v_resolved record;
BEGIN
    IF resolve_api.selector IS NULL OR btrim(resolve_api.selector) = '' THEN
        RAISE EXCEPTION 'CAPABILITY_API_SELECTOR_EMPTY: an api selector is required (database_id=%, scope="%")',
            resolve_api.database_id, resolve_api.scope
            USING ERRCODE = 'FR020';
    END IF;

    -- <module>[.<api_name>][@<scope>] | <api_name>
    v_ref := btrim(resolve_api.selector);

    v_scope_filter := nullif(split_part(v_ref, '@', 2), '');
    v_ref := split_part(v_ref, '@', 1);

    IF split_part(v_ref, '.', 1) LIKE '%\_module' THEN
        v_kind := 'module';
        v_api_filter := nullif(substr(v_ref, length(split_part(v_ref, '.', 1)) + 2), '');
        v_ref := split_part(v_ref, '.', 1);
    ELSE
        v_kind := 'name';

        IF v_ref LIKE '%.%' OR v_scope_filter IS NOT NULL THEN
            RAISE EXCEPTION 'CAPABILITY_API_SELECTOR_INVALID: selector "%" qualifies an api name; only a module selector (<name>_module) takes .api or @scope suffixes',
                resolve_api.selector
                USING ERRCODE = 'FR020';
        END IF;
    END IF;

    IF btrim(coalesce(v_ref, '')) = '' THEN
        RAISE EXCEPTION 'CAPABILITY_API_SELECTOR_INVALID: selector "%" names nothing',
            resolve_api.selector
            USING ERRCODE = 'FR020';
    END IF;

    -- =========================================================================
    -- <api_name> — one indexed read of the apis catalog for every frame
    -- =========================================================================
    IF v_kind = 'name' THEN
        -- Keeps only the matches of the most specific frame that answered: a
        -- nearer frame outranks an outer one, and ties within that frame are the
        -- ambiguity raised below.
        WITH hits AS (
            SELECT a.id,
                   a.name,
                   a.database_id,
                   a.owner_scope,
                   a.owner_key,
                   cand.ord
            FROM function_resolution.frame_candidates(
                resolve_api.database_id,
                resolve_api.scope,
                resolve_api.entity_id
            ) cand
            JOIN catalog_private.apis a
              ON a.owner_scope = cand.owner_scope
             AND a.owner_key IS NOT DISTINCT FROM cand.owner_key
             AND a.database_id = CASE
                   WHEN cand.owner_scope = 'database' THEN cand.owner_key
                   ELSE cand.lookup_database_id
                 END
            WHERE a.name = v_ref
              AND (a.database_id = resolve_api.database_id OR a.is_visible)
        ),
        nearest AS (
            SELECT h.*
            FROM hits h
            WHERE h.ord = (SELECT min(hh.ord) FROM hits hh)
        )
        SELECT COALESCE(jsonb_agg(to_jsonb(n) ORDER BY n.id), '[]'::jsonb)
        INTO v_matches
        FROM nearest n;

        IF jsonb_array_length(v_matches) = 0 THEN
            RAISE EXCEPTION 'CAPABILITY_API_NOT_FOUND: no api named "%" resolves in the scope chain starting at scope "%" (database_id=%)',
                v_ref, resolve_api.scope, resolve_api.database_id
                USING ERRCODE = 'FR021';
        END IF;

        IF jsonb_array_length(v_matches) > 1 THEN
            RAISE EXCEPTION 'CAPABILITY_API_AMBIGUOUS: % apis named "%" resolve equally (candidates: %)',
                jsonb_array_length(v_matches),
                v_ref,
                (SELECT string_agg(format('%s (%s)', m->>'name', m->>'id'), ', ' ORDER BY m->>'id')
                   FROM jsonb_array_elements(v_matches) m)
                USING ERRCODE = 'FR022';
        END IF;

        v_match := v_matches->0;

        resolve_api.api_id := (v_match->>'id')::uuid;
        resolve_api.api_name := v_match->>'name';
        resolve_api.owner_database_id := (v_match->>'database_id')::uuid;
        resolve_api.owner_scope := v_match->>'owner_scope';
        resolve_api.owner_key := (v_match->>'owner_key')::uuid;

        RETURN NEXT;
        RETURN;
    END IF;

    -- =========================================================================
    -- <module>[.<api>][@<scope>] — resolve through the module's api attachment
    -- =========================================================================
    v_module_table := v_ref;

    -- The selector names a module registration table, and a name that is not one
    -- must fail as a typo rather than as "not provisioned". Looked up in the
    -- catalog by name as an ordinary join: the relation is identified by a bind
    -- parameter, so no identifier is interpolated into SQL, and the oid is then
    -- reused for the column checks below instead of being probed again.
    SELECT c.oid
    INTO v_module_relid
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'metaschema_modules_public'
      AND c.relname = v_module_table
      AND c.relkind IN ('r', 'p', 'v', 'm', 'f');

    IF v_module_relid IS NULL THEN
        RAISE EXCEPTION 'CAPABILITY_API_MODULE_UNKNOWN: selector "%" names module "%", which has no registration table in metaschema_modules_public',
            resolve_api.selector, v_ref
            USING ERRCODE = 'FR023';
    END IF;

    -- Not every module registration is scoped: a module whose schemas can only
    -- be attached at one scope has no scope column, and asking for one turns a
    -- valid selector into an error.
    SELECT EXISTS (
        SELECT 1
        FROM pg_attribute a
        WHERE a.attrelid = v_module_relid
          AND a.attname = 'scope'
          AND a.attnum > 0
          AND NOT a.attisdropped
    )
    INTO v_module_has_scope;

    IF v_scope_filter IS NOT NULL AND NOT v_module_has_scope THEN
        RAISE EXCEPTION 'CAPABILITY_API_SELECTOR_INVALID: selector "%" asks for scope "%", but module "%" registers at a single scope',
            resolve_api.selector, v_scope_filter, v_ref
            USING ERRCODE = 'FR020';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_attribute a
        WHERE a.attrelid = v_module_relid
          AND a.attname = 'api_name'
          AND a.attnum > 0
          AND NOT a.attisdropped
    ) THEN
        RAISE EXCEPTION 'CAPABILITY_API_MODULE_UNSUPPORTED: module "%" has no api_name column, so selector "%" cannot name one of its surfaces',
            v_ref, resolve_api.selector
            USING ERRCODE = 'FR023';
    END IF;

    FOR v_frame IN
        SELECT f.lookup_database_id, f.scope, min(f.ord) AS ord
        FROM function_resolution.frame_candidates(
            resolve_api.database_id,
            resolve_api.scope,
            resolve_api.entity_id
        ) f(lookup_database_id, scope, owner_key, ord)
        GROUP BY f.lookup_database_id, f.scope
        ORDER BY min(f.ord)
    LOOP
        -- @scope pins the registration to one scope tier; without it, the
        -- frame being walked supplies the scope, so a department execution
        -- finds its org's registration when the org frame comes up.
        -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the module registration table is named by the selector
        v_query := format(
            'SELECT m.schema_id, m.api_name
               FROM metaschema_modules_public.%I m
              WHERE m.database_id = $1
                %s
              LIMIT 1',
            v_module_table,
            CASE WHEN v_module_has_scope THEN 'AND m.scope = $2' ELSE 'AND $2 IS NOT NULL' END
        );

        CONTINUE WHEN v_scope_filter IS NOT NULL AND v_scope_filter <> v_frame.scope;

        EXECUTE v_query
        INTO v_module_schema_id, v_module_api_name
        USING v_frame.lookup_database_id, v_frame.scope;

        CONTINUE WHEN v_module_schema_id IS NULL;

        SELECT r.apis_schema, r.apis_table, r.api_schemas_schema, r.api_schemas_table
        INTO v_apis_schema, v_apis_table, v_api_schemas_schema, v_api_schemas_table
        FROM app_scope.routing_tables(v_frame.lookup_database_id, v_frame.scope) r;

        CONTINUE WHEN v_apis_schema IS NULL OR v_api_schemas_schema IS NULL;

        -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the api surface tables are located per frame
        v_query := format(
            'SELECT s.api_id AS id, a.name
               FROM %I.%I s
               JOIN %I.%I a ON a.id = s.api_id
              WHERE s.schema_id = $1',
            v_api_schemas_schema, v_api_schemas_table,
            v_apis_schema, v_apis_table
        );

        v_matches := '[]'::jsonb;

        FOR v_row IN EXECUTE v_query USING v_module_schema_id
        LOOP
            v_matches := v_matches || to_jsonb(v_row);
        END LOOP;

        CONTINUE WHEN jsonb_array_length(v_matches) = 0;

        -- .api names the surface outright; a bare module selector finding
        -- several surfaces falls back to the module row's own api_name (the
        -- authored intent). Failing both, the selector is genuinely ambiguous
        -- and must not guess.
        v_match := NULL;

        IF v_api_filter IS NOT NULL THEN
            SELECT m INTO v_match
            FROM jsonb_array_elements(v_matches) m
            WHERE m->>'name' = v_api_filter;

            IF v_match IS NULL THEN
                RAISE EXCEPTION 'CAPABILITY_API_NOT_FOUND: module "%" has no attached api named "%" (candidates: %)',
                    v_ref,
                    v_api_filter,
                    (SELECT string_agg(format('%s (%s)', m->>'name', m->>'id'), ', ' ORDER BY m->>'id')
                       FROM jsonb_array_elements(v_matches) m)
                    USING ERRCODE = 'FR021';
            END IF;
        ELSIF jsonb_array_length(v_matches) > 1 THEN
            SELECT m INTO v_match
            FROM jsonb_array_elements(v_matches) m
            WHERE m->>'name' = v_module_api_name;

            IF v_match IS NULL THEN
                RAISE EXCEPTION 'CAPABILITY_API_AMBIGUOUS: module "%" has schemas attached to % apis (candidates: %) and none matches its api_name "%"; name one with %.<api>',
                    v_ref,
                    jsonb_array_length(v_matches),
                    (SELECT string_agg(format('%s (%s)', m->>'name', m->>'id'), ', ' ORDER BY m->>'id')
                       FROM jsonb_array_elements(v_matches) m),
                    coalesce(v_module_api_name, ''),
                    v_ref
                    USING ERRCODE = 'FR022';
            END IF;
        ELSE
            v_match := v_matches->0;
        END IF;

        SELECT *
        INTO v_resolved
        FROM function_resolution.api_catalog_row(
            resolve_api.database_id,
            resolve_api.scope,
            resolve_api.entity_id,
            (v_match->>'id')::uuid
        );

        -- The attachment names an api the execution cannot reach (another
        -- tenant's, or an outer frame's unpublished surface): that is a
        -- misconfiguration, not a reason to fall through to a further frame.
        IF NOT FOUND THEN
            RAISE EXCEPTION 'CAPABILITY_API_UNREACHABLE: selector "%" resolves to api % via module "%", which is not visible to database %',
                resolve_api.selector, v_match->>'id', v_ref, resolve_api.database_id
                USING ERRCODE = 'FR021';
        END IF;

        resolve_api.api_id := (v_match->>'id')::uuid;
        resolve_api.api_name := v_resolved.api_name;
        resolve_api.owner_database_id := v_resolved.owner_database_id;
        resolve_api.owner_scope := v_resolved.owner_scope;
        resolve_api.owner_key := v_resolved.owner_key;

        RETURN NEXT;
        RETURN;
    END LOOP;

    RAISE EXCEPTION 'CAPABILITY_API_NOT_FOUND: selector "%" resolves no api surface in the scope chain starting at scope "%" (database_id=%): module "%" is either unregistered there%s or has no api attachment',
        resolve_api.selector,
        resolve_api.scope,
        resolve_api.database_id,
        v_ref,
        CASE WHEN v_scope_filter IS NULL THEN '' ELSE format(' at scope "%s"', v_scope_filter) END
        USING ERRCODE = 'FR021';
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.bound_bucket_id(
  database_id uuid,
  scope text,
  entity_id uuid,
  function_definition_id uuid,
  key text
) RETURNS uuid AS $EOFCODE$
DECLARE
    v_bucket_id uuid;
BEGIN
    SELECT b.bucket_id
    INTO v_bucket_id
    FROM function_resolution.frame_candidates(
        bound_bucket_id.database_id,
        bound_bucket_id.scope,
        bound_bucket_id.entity_id
    ) cand
    JOIN catalog_private.bindings b
      ON b.owner_scope = cand.owner_scope
     AND b.owner_key IS NOT DISTINCT FROM cand.owner_key
     AND b.database_id = CASE
           WHEN cand.owner_scope = 'database' THEN cand.owner_key
           ELSE cand.lookup_database_id
         END
    WHERE b.function_id = bound_bucket_id.function_definition_id
      AND b.key = bound_bucket_id.key
      AND b.bucket_id IS NOT NULL
    ORDER BY cand.ord,
             CASE b.lifecycle
                 WHEN 'execution' THEN 0
                 WHEN 'root_execution' THEN 1
                 ELSE 2
             END
    LIMIT 1;

    RETURN v_bucket_id;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.resolve_payload_refs(
  database_id uuid,
  scope text,
  entity_id uuid,
  payload jsonb
) RETURNS jsonb AS $EOFCODE$
DECLARE
    v_kind text;
    v_tags text[];
    v_bucket record;
    v_api record;
    v_selector text;
    v_schema text;
    v_name text;
    v_table_id uuid;
    v_result jsonb;
    v_key text;
BEGIN
    IF resolve_payload_refs.payload IS NULL THEN
        RETURN NULL;
    END IF;

    IF jsonb_typeof(resolve_payload_refs.payload) = 'array' THEN
        SELECT coalesce(jsonb_agg(
                   function_resolution.resolve_payload_refs(
                       resolve_payload_refs.database_id,
                       resolve_payload_refs.scope,
                       resolve_payload_refs.entity_id,
                       elem
                   ) ORDER BY ord
               ), '[]'::jsonb)
        INTO v_result
        FROM jsonb_array_elements(resolve_payload_refs.payload) WITH ORDINALITY AS t(elem, ord);

        RETURN v_result;
    END IF;

    IF jsonb_typeof(resolve_payload_refs.payload) <> 'object' THEN
        RETURN resolve_payload_refs.payload;
    END IF;

    IF NOT (resolve_payload_refs.payload ? '$ref') THEN
        v_result := '{}'::jsonb;

        FOR v_key IN SELECT k FROM jsonb_object_keys(resolve_payload_refs.payload) k
        LOOP
            v_result := v_result || jsonb_build_object(
                v_key,
                function_resolution.resolve_payload_refs(
                    resolve_payload_refs.database_id,
                    resolve_payload_refs.scope,
                    resolve_payload_refs.entity_id,
                    resolve_payload_refs.payload -> v_key
                )
            );
        END LOOP;

        RETURN v_result;
    END IF;

    v_kind := resolve_payload_refs.payload->>'$ref';

    IF v_kind = 'bucket' THEN
        -- Already resolved (trigger-time stamping, or a second pass).
        IF resolve_payload_refs.payload ? 'bucket_id' THEN
            RETURN resolve_payload_refs.payload;
        END IF;

        IF resolve_payload_refs.payload ? 'tags' THEN
            SELECT array_agg(t.tag ORDER BY t.ord)
            INTO v_tags
            FROM jsonb_array_elements_text(resolve_payload_refs.payload->'tags')
                 WITH ORDINALITY AS t(tag, ord);
        ELSIF resolve_payload_refs.payload ? 'key' THEN
            -- A single key is the one-tag selector: the declaration vocabulary
            -- and the payload vocabulary stay the same thing.
            v_tags := ARRAY[resolve_payload_refs.payload->>'key'];
        END IF;

        SELECT *
        INTO v_bucket
        FROM function_resolution.resolve_bucket(
            resolve_payload_refs.database_id,
            resolve_payload_refs.scope,
            resolve_payload_refs.entity_id,
            v_tags,
            resolve_payload_refs.payload->>'type'
        );

        RETURN jsonb_build_object(
            '$ref', 'bucket',
            'bucket_id', v_bucket.bucket_id,
            'key', v_bucket.bucket_key,
            'type', v_bucket.bucket_type,
            'physical_name', v_bucket.physical_name,
            'database_id', v_bucket.owner_database_id
        );
    END IF;

    IF v_kind = 'api' THEN
        IF resolve_payload_refs.payload ? 'api_id' THEN
            RETURN resolve_payload_refs.payload;
        END IF;

        -- Both keys carry the selector vocabulary itself: module is a module
        -- name (optionally .api / @scope), name is an api name.
        v_selector := coalesce(
            resolve_payload_refs.payload->>'module',
            resolve_payload_refs.payload->>'name'
        );

        SELECT *
        INTO v_api
        FROM function_resolution.resolve_api(
            resolve_payload_refs.database_id,
            resolve_payload_refs.scope,
            resolve_payload_refs.entity_id,
            v_selector
        );

        RETURN jsonb_build_object(
            '$ref', 'api',
            'api_id', v_api.api_id,
            'name', v_api.api_name,
            'database_id', v_api.owner_database_id
        );
    END IF;

    IF v_kind = 'table' THEN
        IF resolve_payload_refs.payload ? 'table_id' THEN
            RETURN resolve_payload_refs.payload;
        END IF;

        v_schema := resolve_payload_refs.payload->>'schema';
        v_name := resolve_payload_refs.payload->>'name';

        IF v_schema IS NULL OR v_name IS NULL THEN
            RAISE EXCEPTION 'CAPABILITY_TABLE_REF_INVALID: a table reference needs both schema and name (got %)',
                resolve_payload_refs.payload
                USING ERRCODE = 'FR031';
        END IF;

        SELECT t.id
        INTO v_table_id
        FROM metaschema_public.schema s
        JOIN metaschema_public."table" t ON (t.schema_id = s.id AND t.database_id = s.database_id)
        WHERE s.database_id = resolve_payload_refs.database_id
          AND s.schema_name = v_schema
          AND t.name = v_name;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'CAPABILITY_TABLE_NOT_FOUND: database % has no table %.%',
                resolve_payload_refs.database_id, v_schema, v_name
                USING ERRCODE = 'FR032';
        END IF;

        RETURN jsonb_build_object(
            '$ref', 'table',
            'schema', v_schema,
            'name', v_name,
            'table_id', v_table_id
        );
    END IF;

    RAISE EXCEPTION 'CAPABILITY_REF_UNKNOWN: "%" is not a known payload reference kind (known kinds: bucket, table, api)',
        v_kind
        USING ERRCODE = 'FR030';
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.resolve_capabilities(
  database_id uuid,
  scope text,
  entity_id uuid,
  function_definition_id uuid,
  definition_scope text,
  definition_database_id uuid DEFAULT NULL,
  payload jsonb DEFAULT '{}'::jsonb,
  channel text DEFAULT NULL
) RETURNS jsonb AS $EOFCODE$
DECLARE
    v_defn_database_id uuid;
    v_defs_schema text;
    v_defs_table text;
    v_query text;
    v_definition jsonb;
    v_access_channels text[];
    v_key text;
    v_bound_bucket_id uuid;
    -- The keys a tenant fulfilled with an explicit binding, paired positionally
    -- with the bucket each binding names: the two resolution routes are disjoint
    -- sets of keys, resolved by one query each rather than key by key.
    v_bound_keys text[];
    v_bound_ids uuid[];
    v_buckets jsonb := '{}'::jsonb;
    v_apis jsonb := '{}'::jsonb;
BEGIN
    v_defn_database_id := coalesce(
        resolve_capabilities.definition_database_id,
        resolve_capabilities.database_id
    );

    SELECT l.schema_name, l.table_name
    INTO v_defs_schema, v_defs_table
    FROM function_resolution.definitions_location(v_defn_database_id, resolve_capabilities.definition_scope) l;

    IF v_defs_schema IS NULL THEN
        RAISE EXCEPTION 'CAPABILITY_DEFINITION_SCOPE_UNPROVISIONED: database % has no function module at scope "%"',
            v_defn_database_id, resolve_capabilities.definition_scope
            USING ERRCODE = 'FR040';
    END IF;

    -- to_jsonb of the row rather than a column list: the declaration set grows,
    -- and a resolver that names columns fails on a database whose function
    -- module predates the newest one.
    -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the definitions table is located per scope
    v_query := format('SELECT to_jsonb(d) FROM %I.%I d WHERE d.id = $1', v_defs_schema, v_defs_table);

    EXECUTE v_query INTO v_definition USING resolve_capabilities.function_definition_id;

    IF v_definition IS NULL THEN
        RAISE EXCEPTION 'CAPABILITY_DEFINITION_NOT_FOUND: no function definition % at scope "%" in database %',
            resolve_capabilities.function_definition_id,
            resolve_capabilities.definition_scope,
            v_defn_database_id
            USING ERRCODE = 'FR040';
    END IF;

    -- Lane check: access_channels is who may invoke a function, so an
    -- invocation arriving through a channel the definition does not list is
    -- refused here rather than at the image, which cannot know.
    IF resolve_capabilities.channel IS NOT NULL THEN
        SELECT array_agg(c.channel)
        INTO v_access_channels
        FROM jsonb_array_elements_text(coalesce(v_definition->'access_channels', '[]'::jsonb)) AS c(channel);

        IF NOT coalesce(v_access_channels, ARRAY[]::text[]) @> ARRAY[resolve_capabilities.channel] THEN
            RAISE EXCEPTION 'CAPABILITY_CHANNEL_REFUSED: function % does not declare the "%" access channel (declares: %)',
                resolve_capabilities.function_definition_id,
                resolve_capabilities.channel,
                coalesce(array_to_string(v_access_channels, ', '), '')
                USING ERRCODE = 'FR041';
        END IF;
    END IF;

    -- =========================================================================
    -- required_buckets: explicit binding first, then discovery by tag
    --
    -- Set-based, in three statements rather than a loop per key, because every
    -- declared key resolves independently: the bindings are read once, the
    -- reachability of all of them is proved once, and the remaining keys are
    -- resolved by tag once. The two routes are kept in separate statements on
    -- purpose — resolve_bucket RAISES when a tag matches nothing, so evaluating
    -- it for a bound key (which needs no tag) would turn a valid declaration
    -- into an error, and a LEFT JOIN LATERAL's ON clause is no guarantee the
    -- function is not evaluated.
    -- =========================================================================
    SELECT array_agg(b.key ORDER BY b.ord), array_agg(b.bucket_id ORDER BY b.ord)
    INTO v_bound_keys, v_bound_ids
    FROM (
        SELECT k.key,
               k.ord,
               function_resolution.bound_bucket_id(
                   resolve_capabilities.database_id,
                   resolve_capabilities.scope,
                   resolve_capabilities.entity_id,
                   resolve_capabilities.function_definition_id,
                   k.key
               ) AS bucket_id
        FROM jsonb_array_elements_text(
            coalesce(v_definition->'required_buckets', '[]'::jsonb)
        ) WITH ORDINALITY AS k(key, ord)
    ) b
    WHERE b.bucket_id IS NOT NULL;

    -- Same-tenant enforcement: a binding naming a bucket outside the execution's
    -- own frame chain (or an outer frame's private one) must fail the whole
    -- invocation. The generated binding guard cannot check this — compute's
    -- published modules may not reference storage — so it is checked here, where
    -- a function would otherwise be handed the bucket.
    IF v_bound_keys IS NOT NULL THEN
        SELECT b.key, b.bucket_id
        INTO v_key, v_bound_bucket_id
        FROM unnest(v_bound_keys, v_bound_ids) AS b(key, bucket_id)
        WHERE NOT EXISTS (
            SELECT 1
            FROM function_resolution.bucket_catalog_row(
                resolve_capabilities.database_id,
                resolve_capabilities.scope,
                resolve_capabilities.entity_id,
                b.bucket_id
            )
        )
        ORDER BY b.key
        LIMIT 1;

        IF FOUND THEN
            RAISE EXCEPTION 'CAPABILITY_BINDING_UNREACHABLE: capability "%" of function % is bound to bucket %, which database % may not reach',
                v_key,
                resolve_capabilities.function_definition_id,
                v_bound_bucket_id,
                resolve_capabilities.database_id
                USING ERRCODE = 'FR013';
        END IF;

        SELECT jsonb_object_agg(b.key, jsonb_build_object(
            'bucket_id', b.bucket_id,
            'key', c.bucket_key,
            'type', c.bucket_type,
            'physical_name', c.physical_name,
            'database_id', c.owner_database_id,
            'source', 'binding'
        ))
        INTO v_buckets
        FROM unnest(v_bound_keys, v_bound_ids) AS b(key, bucket_id)
        CROSS JOIN LATERAL function_resolution.bucket_catalog_row(
            resolve_capabilities.database_id,
            resolve_capabilities.scope,
            resolve_capabilities.entity_id,
            b.bucket_id
        ) c;
    END IF;

    -- Discovery by tag, for every declared key the tenant did not bind. The
    -- unbound set is a MATERIALIZED CTE so the bound keys are excluded *before*
    -- resolve_bucket runs: a bound key needs no tag, and evaluating it would
    -- raise CAPABILITY_BUCKET_NOT_FOUND on a perfectly valid declaration.
    WITH unbound AS MATERIALIZED (
        SELECT k.key
        FROM jsonb_array_elements_text(
            coalesce(v_definition->'required_buckets', '[]'::jsonb)
        ) AS k(key)
        WHERE NOT k.key = ANY(coalesce(v_bound_keys, ARRAY[]::text[]))
    )
    SELECT coalesce(v_buckets, '{}'::jsonb) || coalesce(jsonb_object_agg(k.key, jsonb_build_object(
        'bucket_id', r.bucket_id,
        'key', r.bucket_key,
        'type', r.bucket_type,
        'physical_name', r.physical_name,
        'database_id', r.owner_database_id,
        'source', 'tags'
    )), '{}'::jsonb)
    INTO v_buckets
    FROM unbound k
    CROSS JOIN LATERAL function_resolution.resolve_bucket(
        resolve_capabilities.database_id,
        resolve_capabilities.scope,
        resolve_capabilities.entity_id,
        ARRAY[k.key],
        NULL
    ) r;

    -- =========================================================================
    -- required_modules: module names, the same vocabulary the presets use
    -- (<module>[.<api>][@<scope>], or a bare api name as the escape hatch).
    -- resolve_api raises on an unresolvable selector, which propagates out of
    -- the lateral and fails the invocation — the intended behaviour.
    -- =========================================================================
    SELECT coalesce(jsonb_object_agg(s.selector, jsonb_build_object(
        'api_id', a.api_id,
        'name', a.api_name,
        'database_id', a.owner_database_id
    )), '{}'::jsonb)
    INTO v_apis
    FROM jsonb_array_elements_text(
        coalesce(v_definition->'required_modules', '[]'::jsonb)
    ) AS s(selector)
    CROSS JOIN LATERAL function_resolution.resolve_api(
        resolve_capabilities.database_id,
        resolve_capabilities.scope,
        resolve_capabilities.entity_id,
        s.selector
    ) a;

    RETURN jsonb_build_object(
        'function_definition_id', resolve_capabilities.function_definition_id,
        'definition_scope', resolve_capabilities.definition_scope,
        'definition_database_id', v_defn_database_id,
        'database_id', resolve_capabilities.database_id,
        'scope', resolve_capabilities.scope,
        'entity_id', resolve_capabilities.entity_id,
        'buckets', v_buckets,
        'apis', v_apis,
        'models', coalesce(v_definition->'required_models', '[]'::jsonb),
        'secrets', coalesce(v_definition->'required_secrets', '[]'::jsonb),
        'configs', coalesce(v_definition->'required_configs', '[]'::jsonb),
        'integrations', coalesce(v_definition->'integrations', '[]'::jsonb),
        'access_channels', coalesce(v_definition->'access_channels', '[]'::jsonb),
        'payload', function_resolution.resolve_payload_refs(
            resolve_capabilities.database_id,
            resolve_capabilities.scope,
            resolve_capabilities.entity_id,
            coalesce(resolve_capabilities.payload, '{}'::jsonb)
        )
    );
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.validate_capabilities(
  database_id uuid,
  scope text,
  entity_id uuid,
  function_definition_id uuid,
  definition_scope text,
  definition_database_id uuid DEFAULT NULL,
  payload jsonb DEFAULT '{}'::jsonb,
  channel text DEFAULT NULL
) RETURNS void AS $EOFCODE$
BEGIN
    PERFORM function_resolution.resolve_capabilities(
        validate_capabilities.database_id,
        validate_capabilities.scope,
        validate_capabilities.entity_id,
        validate_capabilities.function_definition_id,
        validate_capabilities.definition_scope,
        validate_capabilities.definition_database_id,
        validate_capabilities.payload,
        validate_capabilities.channel
    );
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;