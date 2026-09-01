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
  db_id uuid DEFAULT jwt_private.require_database_id(),
  actor_id uuid DEFAULT jwt_public.current_user_id(),
  principal_id uuid DEFAULT jwt_public.current_principal_id()
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
        db_id := v_database_id,
        actor_id := enqueue.actor_id,
        principal_id := enqueue.principal_id
    );
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION function_resolution.enqueue(text, pg_catalog.json, text, uuid, uuid, text, text, text, timestamptz, int, int, uuid, text, boolean, text, uuid, uuid, uuid, uuid) IS 'Resolver-aware job enqueue: resolves (or trusts a supplied) function definition for the execution (database, scope, entity, task_identifier), stamps the (function_definition_id, definition_scope) pair and the definition''s queue routing, then delegates the insert to app_jobs.add_job. The single enqueue path for function jobs; definition-less tasks enqueue with a NULL pair. Portable: built only on app_scope + the metaschema catalog + app_jobs, no AST/deparser runtime.';

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

CREATE FUNCTION function_resolution.staging_bucket_tag() RETURNS text AS $EOFCODE$
    SELECT 'default-temp';
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION function_resolution.resolve_staging_bucket(
  database_id uuid,
  scope text,
  entity_id uuid
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
    v_tag := function_resolution.staging_bucket_tag();

    SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m.bucket_id), '[]'::jsonb)
    INTO v_matches
    FROM function_resolution.bucket_matches(
        resolve_staging_bucket.database_id,
        resolve_staging_bucket.scope,
        resolve_staging_bucket.entity_id,
        ARRAY[v_tag],
        'temp'
    ) m;

    IF jsonb_array_length(v_matches) = 0 THEN
        PERFORM errors.raise_error(
            'STORAGE_STAGING_BUCKET_NOT_FOUND',
            jsonb_build_object(
                'database_id', resolve_staging_bucket.database_id,
                'scope', resolve_staging_bucket.scope,
                'entity_id', resolve_staging_bucket.entity_id,
                'tag', v_tag
            ),
            'internal'
        );
    END IF;

    IF jsonb_array_length(v_matches) > 1 THEN
        PERFORM errors.raise_error(
            'STORAGE_STAGING_BUCKET_AMBIGUOUS',
            jsonb_build_object(
                'database_id', resolve_staging_bucket.database_id,
                'scope', resolve_staging_bucket.scope,
                'entity_id', resolve_staging_bucket.entity_id,
                'tag', v_tag,
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

    resolve_staging_bucket.bucket_id := (v_match->>'bucket_id')::uuid;
    resolve_staging_bucket.resolved_key := v_match->>'bucket_key';
    resolve_staging_bucket.bucket_type := v_match->>'bucket_type';
    resolve_staging_bucket.physical_name := v_match->>'physical_name';
    resolve_staging_bucket.owner_database_id := (v_match->>'owner_database_id')::uuid;
    resolve_staging_bucket.owner_scope := v_match->>'owner_scope';
    resolve_staging_bucket.owner_key := (v_match->>'owner_key')::uuid;

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

CREATE FUNCTION function_resolution.image_catalog_row(
  database_id uuid,
  scope text,
  entity_id uuid,
  image_name text
) RETURNS TABLE (
  image_id uuid,
  name text,
  registry_host text,
  repository text,
  tag text,
  digest text,
  runtime text,
  labels jsonb,
  owner_database_id uuid,
  owner_scope text,
  owner_key uuid
) AS $EOFCODE$
BEGIN
    RETURN QUERY
    SELECT i.id,
           i.name,
           i.registry_host,
           i.repository,
           i.tag,
           i.digest,
           i.runtime,
           i.labels,
           i.database_id,
           i.owner_scope,
           i.owner_key
    FROM function_resolution.frame_candidates(
        image_catalog_row.database_id,
        image_catalog_row.scope,
        image_catalog_row.entity_id
    ) cand
    JOIN catalog_private.images i
      ON i.owner_scope = cand.owner_scope
     AND i.owner_key IS NOT DISTINCT FROM cand.owner_key
     AND i.database_id = CASE
           WHEN cand.owner_scope = 'database' THEN cand.owner_key
           ELSE cand.lookup_database_id
         END
    WHERE i.name = image_catalog_row.image_name
      AND (
            i.database_id = image_catalog_row.database_id
            OR (i.is_visible AND NOT i.platform_only)
          )
    ORDER BY cand.ord
    LIMIT 1;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE FUNCTION function_resolution.install_route_bindings(
  database_id uuid,
  sites_schema text,
  sites_table text,
  site_id uuid,
  bindings jsonb,
  entity_id uuid DEFAULT NULL
) RETURNS jsonb AS $EOFCODE$
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
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

COMMENT ON FUNCTION function_resolution.install_route_bindings(uuid, text, text, uuid, jsonb, uuid) IS 'Install a set of route bindings — a JSON array of {path, target, …} entries, each NAMING its target kind ("function" with a task_identifier, or "service" with a service_id) — onto one site as ordinary route rows, at ONE scope for ONE entity. The scope and ownership key are read from the named sites plane''s own site_surface_module registration, located along the caller''s frames (nearest first) so a shared serving plane hosted by an outer frame''s database resolves for the tenant consuming it — never a caller-supplied or generated literal — and that one (scope, key) then names the routes plane (app_scope.routing_tables), pins the site, route and service reads, starts function_resolution.resolve''s frame walk, and stamps every inserted row; a service target is proved to exist in the same-scope resources plane the routes plane''s registration records, which is the plane target_service_id FKs. Idempotent per (domain_id, path); raises on a malformed document, an unknown or ambiguous target kind, an unregistered plane, a scope with no routes plane, a missing entity key, an unknown site, an unrouted site, a scope with no resources plane, an unresolvable service, or an unpublished task.';

CREATE FUNCTION function_resolution.install_mantra(
  database_id uuid,
  sites_plane regclass,
  site_id uuid,
  bindings jsonb,
  entity_id uuid DEFAULT NULL
) RETURNS jsonb AS $EOFCODE$
DECLARE
    function_bindings jsonb;
    sites_schema text;
    sites_table text;
BEGIN
    IF install_mantra.sites_plane IS NULL THEN
        RAISE EXCEPTION 'MANTRA_SITES_PLANE_REQUIRED: sites_plane is required'
            USING ERRCODE = 'FR050';
    END IF;

    -- The plane's names, read off the catalog entry the reference itself proves
    -- exists, and handed to the engine as the registry records them.
    SELECT n.nspname, c.relname
    INTO sites_schema, sites_table
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE c.oid = install_mantra.sites_plane;

    -- The Mantra document contract, checked here because it is stricter than the
    -- engine's: every entry names a task, and none of them may name a target
    -- kind — a preset row that has grown a service binding is a broken preset,
    -- not a mixed install.
    IF install_mantra.bindings IS NULL
       OR jsonb_typeof(install_mantra.bindings) <> 'array'
       OR jsonb_array_length(install_mantra.bindings) = 0 THEN
        RAISE EXCEPTION 'MANTRA_BINDINGS_INVALID: bindings must be a non-empty JSON array of {path, task_identifier}, got %',
            coalesce(jsonb_typeof(install_mantra.bindings), 'null')
            USING ERRCODE = 'FR060';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(install_mantra.bindings) AS b
        WHERE jsonb_typeof(b) <> 'object'
           OR coalesce(b ->> 'path', '') = ''
           OR coalesce(b ->> 'task_identifier', '') = ''
           OR b ? 'target'
    ) THEN
        RAISE EXCEPTION 'MANTRA_BINDINGS_INVALID: every binding must carry a non-empty path and task_identifier, and no target kind'
            USING ERRCODE = 'FR060';
    END IF;

    SELECT jsonb_agg(b || jsonb_build_object('target', 'function'))
    INTO function_bindings
    FROM jsonb_array_elements(install_mantra.bindings) AS b;

    RETURN function_resolution.install_route_bindings(
        install_mantra.database_id,
        sites_schema,
        sites_table,
        install_mantra.site_id,
        function_bindings,
        install_mantra.entity_id
    );
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

COMMENT ON FUNCTION function_resolution.install_mantra(uuid, regclass, uuid, jsonb, uuid) IS 'Install the Mantra page set (a JSON array of {path, task_identifier}, which the generated verb reads from the content_presets catalog at kind ''route_bindings'') onto one site as ordinary function-target routes. The sites plane arrives by reference as a regclass, so a generated caller never spells a schema name in a bare string literal the platform export''s AST rename cannot follow. A thin wrapper holding the Mantra document contract — every entry names a task, none names a target kind — over function_resolution.install_route_bindings, which owns the one-scope install: scope and ownership key read from the sites plane''s own registration, the routes plane from app_scope.routing_tables, resolution at that same (scope, entity), idempotent per (domain_id, path).';

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
) AS $EOFCODE$
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
$EOFCODE$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION function_resolution.create_invocation(uuid, text, text, jsonb, text, jsonb, uuid, uuid) IS 'Open one running sync invocation row in the addressed database''s own invocations plane, under the caller''s request role. Proves the session''s database claim, that the task resolves to a definition declaring the sync channel, and — for an anonymous caller — that the definition declares anonymous_callable and that the named route binding is active, targets that definition and declares anonymous access. Attribution and the (function_definition_id, definition_scope) pair are stamped by the plane''s own BEFORE INSERT trigger from the transaction claims.';

GRANT USAGE ON SCHEMA function_resolution TO anonymous;

GRANT EXECUTE ON FUNCTION function_resolution.create_invocation(uuid, text, text, jsonb, text, jsonb, uuid, uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION function_resolution.create_invocation(uuid, text, text, jsonb, text, jsonb, uuid, uuid) TO anonymous;