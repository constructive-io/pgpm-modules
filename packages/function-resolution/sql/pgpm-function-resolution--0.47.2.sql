\echo Use "CREATE EXTENSION pgpm-function-resolution" to load this file. \quit
CREATE SCHEMA IF NOT EXISTS function_resolution;

GRANT USAGE ON SCHEMA function_resolution TO administrator;

GRANT USAGE ON SCHEMA function_resolution TO authenticated;

GRANT USAGE ON SCHEMA function_resolution TO anonymous;

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
    SELECT DISTINCT f.lookup_database_id
    INTO v_unanswerable
    FROM function_resolution.frame_candidates(
        resolve.database_id,
        resolve.scope,
        resolve.entity_id
    ) f
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
    FROM function_resolution.frame_candidates(
        resolve.database_id,
        resolve.scope,
        resolve.entity_id
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
  payload jsonb DEFAULT '{}'::jsonb,
  channel text DEFAULT NULL
) RETURNS jsonb AS $EOFCODE$
DECLARE
    -- The frame whose function surface holds the definition: where the row
    -- physically is (lookup database, schema, table) and whose it is (key).
    frame record;
    surface_found boolean := false;
    definition_database_id uuid;
    definition_query text;
    definition jsonb;
    access_channels text[];
    unreachable_key text;
    unreachable_bucket_id uuid;
    -- The keys a tenant fulfilled with an explicit binding, paired positionally
    -- with the bucket each binding names: the two resolution routes are disjoint
    -- sets of keys, resolved by one query each rather than key by key.
    bound_keys text[];
    bound_ids uuid[];
    buckets jsonb := '{}'::jsonb;
    apis jsonb := '{}'::jsonb;
BEGIN
    FOR frame IN
        SELECT f.lookup_database_id, f.key_value, l.schema_name, l.table_name, l.entity_field
        FROM app_scope.frames(
            resolve_capabilities.database_id,
            resolve_capabilities.scope,
            resolve_capabilities.entity_id
        ) WITH ORDINALITY AS f(scope, lookup_database_id, key_value, ord)
        CROSS JOIN LATERAL function_resolution.definitions_location(f.lookup_database_id, f.scope) l
        WHERE f.scope = resolve_capabilities.definition_scope
        ORDER BY f.ord
    LOOP
        surface_found := true;

        -- to_jsonb of the row rather than a column list: the declaration set
        -- grows, and a resolver that names columns fails on a database whose
        -- function module predates the newest one. The row must carry the
        -- frame's key in the module's recorded scope-key column; a global frame
        -- has neither, and its key is asserted NULL.
        -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the definitions table is located per frame
        definition_query := format(
            'SELECT to_jsonb(d) FROM %I.%I d WHERE d.id = $1 AND %s',
            frame.schema_name,
            frame.table_name,
            CASE
                WHEN frame.entity_field IS NULL THEN '$2::uuid IS NULL'
                ELSE format('d.%I = $2', frame.entity_field)
            END
        );

        EXECUTE definition_query
        INTO definition
        USING resolve_capabilities.function_definition_id, frame.key_value;

        IF definition IS NOT NULL THEN
            definition_database_id := frame.lookup_database_id;
            EXIT;
        END IF;
    END LOOP;

    IF NOT surface_found THEN
        RAISE EXCEPTION 'CAPABILITY_DEFINITION_SCOPE_UNPROVISIONED: no frame of database % (scope "%") has a function module at scope "%"',
            resolve_capabilities.database_id,
            resolve_capabilities.scope,
            resolve_capabilities.definition_scope
            USING ERRCODE = 'FR040';
    END IF;

    IF definition IS NULL THEN
        RAISE EXCEPTION 'CAPABILITY_DEFINITION_NOT_FOUND: no function definition % at scope "%" reachable from database % (scope "%")',
            resolve_capabilities.function_definition_id,
            resolve_capabilities.definition_scope,
            resolve_capabilities.database_id,
            resolve_capabilities.scope
            USING ERRCODE = 'FR040';
    END IF;

    -- Lane check: access_channels is who may invoke a function, so an
    -- invocation arriving through a channel the definition does not list is
    -- refused here rather than at the image, which cannot know.
    IF resolve_capabilities.channel IS NOT NULL THEN
        SELECT array_agg(c.channel)
        INTO access_channels
        FROM jsonb_array_elements_text(coalesce(definition->'access_channels', '[]'::jsonb)) AS c(channel);

        IF NOT coalesce(access_channels, ARRAY[]::text[]) @> ARRAY[resolve_capabilities.channel] THEN
            RAISE EXCEPTION 'CAPABILITY_CHANNEL_REFUSED: function % does not declare the "%" access channel (declares: %)',
                resolve_capabilities.function_definition_id,
                resolve_capabilities.channel,
                coalesce(array_to_string(access_channels, ', '), '')
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
    INTO bound_keys, bound_ids
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
            coalesce(definition->'required_buckets', '[]'::jsonb)
        ) WITH ORDINALITY AS k(key, ord)
    ) b
    WHERE b.bucket_id IS NOT NULL;

    -- Same-tenant enforcement: a binding naming a bucket outside the execution's
    -- own frame chain (or an outer frame's private one) must fail the whole
    -- invocation. The generated binding guard cannot check this — compute's
    -- published modules may not reference storage — so it is checked here, where
    -- a function would otherwise be handed the bucket.
    IF bound_keys IS NOT NULL THEN
        SELECT b.key, b.bucket_id
        INTO unreachable_key, unreachable_bucket_id
        FROM unnest(bound_keys, bound_ids) AS b(key, bucket_id)
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
                unreachable_key,
                resolve_capabilities.function_definition_id,
                unreachable_bucket_id,
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
        INTO buckets
        FROM unnest(bound_keys, bound_ids) AS b(key, bucket_id)
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
            coalesce(definition->'required_buckets', '[]'::jsonb)
        ) AS k(key)
        WHERE NOT k.key = ANY(coalesce(bound_keys, ARRAY[]::text[]))
    )
    SELECT coalesce(buckets, '{}'::jsonb) || coalesce(jsonb_object_agg(k.key, jsonb_build_object(
        'bucket_id', r.bucket_id,
        'key', r.bucket_key,
        'type', r.bucket_type,
        'physical_name', r.physical_name,
        'database_id', r.owner_database_id,
        'source', 'tags'
    )), '{}'::jsonb)
    INTO buckets
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
    INTO apis
    FROM jsonb_array_elements_text(
        coalesce(definition->'required_modules', '[]'::jsonb)
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
        'definition_database_id', definition_database_id,
        'database_id', resolve_capabilities.database_id,
        'scope', resolve_capabilities.scope,
        'entity_id', resolve_capabilities.entity_id,
        'buckets', buckets,
        'apis', apis,
        'models', coalesce(definition->'required_models', '[]'::jsonb),
        'secrets', coalesce(definition->'required_secrets', '[]'::jsonb),
        'configs', coalesce(definition->'required_configs', '[]'::jsonb),
        'integrations', coalesce(definition->'integrations', '[]'::jsonb),
        'access_channels', coalesce(definition->'access_channels', '[]'::jsonb),
        -- Not coalesced: NULL means the handler declared nothing and gets the
        -- full platform set, an empty array means it declared none.
        'capabilities', definition->'required_capabilities',
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
    -- The routes plane's own redirects table, from the same route_module
    -- registration that names the routes table; it shares the plane's
    -- ownership key. NULL when the plane records none, which makes a redirect
    -- binding a hard error rather than an unchecked insert.
    redirects_schema text;
    redirects_table text;
    -- The hostname the site is routed on: a redirect binding's default to_host.
    domains_schema text;
    domains_table text;
    domain_hostname text;
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
    entry_to_host text;
    entry_to_path text;
    entry_status int;
    entry_redirect_name text;
    target_column text;
    target_id uuid;
    service_found boolean;
    inserted int;
    repointed_now int;
    installed jsonb := '[]'::jsonb;
    skipped jsonb := '[]'::jsonb;
    repointed jsonb := '[]'::jsonb;
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
        WHERE (b ->> 'target') NOT IN ('function', 'service', 'redirect')
    ) THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_TARGET_UNKNOWN: target must be "function", "service" or "redirect"'
            USING ERRCODE = 'FR060';
    END IF;

    -- A binding carrying the key of a kind it did not declare is ambiguous, and
    -- resolving it by precedence would let a typo repoint a path at a different
    -- plane than the document reads like.
    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(install_route_bindings.bindings) AS b
        WHERE (b ? 'task_identifier') AND (b ? 'service_id')
           OR (b ->> 'target') = 'function' AND (b ? 'service_id' OR b ? 'to_path')
           OR (b ->> 'target') = 'service' AND (b ? 'task_identifier' OR b ? 'to_path')
           OR (b ->> 'target') = 'redirect' AND (b ? 'task_identifier' OR b ? 'service_id')
    ) THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_TARGET_AMBIGUOUS: a binding must carry only the key of the target kind it declares'
            USING ERRCODE = 'FR060';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(install_route_bindings.bindings) AS b
        WHERE (b ->> 'target') = 'function' AND coalesce(b ->> 'task_identifier', '') = ''
           OR (b ->> 'target') = 'service' AND coalesce(b ->> 'service_id', '') = ''
           OR (b ->> 'target') = 'redirect' AND coalesce(b ->> 'to_path', '') = ''
    ) THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_INVALID: a function binding needs a task_identifier, a service binding needs a service_id, and a redirect binding needs a to_path'
            USING ERRCODE = 'FR060';
    END IF;

    -- A redirect's destination is a path on a host, so it must read as one, and
    -- its status must be one the edge can honour (the same set the redirects
    -- table's own check constraint accepts — rejected here by name rather than
    -- as a constraint violation naming no binding).
    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(install_route_bindings.bindings) AS b
        WHERE (b ->> 'target') = 'redirect'
          AND (
               (b ->> 'to_path') !~ '^/'
            OR (b ? 'to_host' AND coalesce(b ->> 'to_host', '') = '')
            OR (b ? 'status_code' AND NOT (b -> 'status_code' <@ '[301, 302, 307, 308]'::jsonb))
          )
    ) THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_REDIRECT_INVALID: a redirect binding''s to_path must start with "/", its to_host (when given) must be non-empty, and its status_code (when given) must be 301, 302, 307 or 308'
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
    SELECT r.routes_schema, r.routes_table, r.domains_schema, r.domains_table
    INTO routes_schema, routes_table, domains_schema, domains_table
    FROM app_scope.routing_tables(install_route_bindings.database_id, plane_scope) AS r;

    IF routes_schema IS NULL OR routes_table IS NULL THEN
        RAISE EXCEPTION 'ROUTE_BINDINGS_ROUTES_PLANE_NOT_FOUND: scope "%" has no routes plane provisioned on any frame of database %',
            plane_scope, install_route_bindings.database_id
            USING ERRCODE = 'FR051';
    END IF;

    -- The routes plane's own registration carries its ownership key, the
    -- column naming the site a route renders as (when the plane has one), and
    -- the redirects table a redirect binding writes (when it records one).
    SELECT rm.entity_field, rm.serving_site_field, rs.schema_name, rt.name
    INTO routes_key, routes_serving_site_key, redirects_schema, redirects_table
    FROM metaschema_modules_public.route_module AS rm
    JOIN metaschema_public."table" AS t ON t.id = rm.routes_table_id
    JOIN metaschema_public.schema AS s ON s.id = t.schema_id
    LEFT JOIN metaschema_public."table" AS rt
      ON rt.id = rm.redirects_table_id
     AND rm.redirects_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.schema AS rs ON rs.id = rt.schema_id
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
    --    empty install. A route this install stamped as serving the site counts
    --    too: once a redirect has taken the root over, the pages (serving-site
    --    stamped, function-targeted) are what still tie the host to the site.
    -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the routes plane is named by app_scope.routing_tables
    query := format(
        'SELECT r.domain_id FROM %I.%I AS r WHERE (r.target_site_id = $1%s)%s ORDER BY r.path LIMIT 1',
        routes_schema,
        routes_table,
        CASE WHEN routes_serving_site_key IS NULL
             THEN ''
             ELSE format(' OR r.%I = $1', routes_serving_site_key)
        END,
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

    -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the domains plane is named by app_scope.routing_tables
    query := format(
        'SELECT d.hostname FROM %I.%I AS d WHERE d.id = $1',
        domains_schema,
        domains_table
    );

    EXECUTE query INTO domain_hostname USING domain_id;

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
        ELSIF entry_target = 'redirect' THEN
            IF redirects_schema IS NULL THEN
                RAISE EXCEPTION 'ROUTE_BINDINGS_REDIRECT_PLANE_NOT_FOUND: routes plane %.% records no redirects table, so there is nowhere a redirect target could live',
                    routes_schema, routes_table
                    USING ERRCODE = 'FR055';
            END IF;

            entry_to_host := coalesce(entry ->> 'to_host', domain_hostname);
            entry_to_path := entry ->> 'to_path';
            entry_status := coalesce((entry ->> 'status_code')::int, 302);
            -- Names are owner-local, so the hostname keeps two sites' roots apart.
            entry_redirect_name := coalesce(entry ->> 'name', format('%s %s', domain_hostname, entry_path));

            -- The redirect row, found by name or created: same insert-if-missing
            -- contract as the routes, so a re-run never rewrites a redirect a
            -- tenant has since retuned.
            -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the redirects plane is named by the routes plane's own route_module registration
            query := format(
                'SELECT rd.id FROM %I.%I AS rd WHERE rd.name = $1%s',
                redirects_schema,
                redirects_table,
                CASE WHEN routes_key IS NULL
                     THEN ' AND $2 IS NULL'
                     ELSE format(' AND rd.%I = $2', routes_key)
                END
            );

            EXECUTE query INTO target_id USING entry_redirect_name, key_value;

            IF target_id IS NULL THEN
                -- pgsql-lint-disable-next-line no-dynamic-sql -- write-only: insert into the redirects plane named by the route_module registration; every value is a bound parameter
                query := format(
                    'INSERT INTO %I.%I (%sname, to_host, to_path, status_code, preserve_path, preserve_query)
                     VALUES (%s$1, $2, $3, $4, false, true)
                     RETURNING id',
                    redirects_schema,
                    redirects_table,
                    CASE WHEN routes_key IS NULL THEN '' ELSE format('%I, ', routes_key) END,
                    CASE WHEN routes_key IS NULL THEN '' ELSE '$5, ' END
                );

                EXECUTE query INTO target_id
                    USING entry_redirect_name, entry_to_host, entry_to_path, entry_status, key_value;
            END IF;

            target_column := 'target_redirect_id';
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

        repointed_now := 0;
        IF inserted = 0 AND entry_target = 'redirect' THEN
            -- The root guard's placeholder — the path exists and still targets
            -- the site this install is for — is the one row a redirect binding
            -- takes over. Anything a tenant has pointed elsewhere stays.
            -- pgsql-lint-disable-next-line no-dynamic-sql -- write-only: update the routes plane named by app_scope.routing_tables; every value is a bound parameter
            query := format(
                'UPDATE %I.%I AS r
                    SET target_site_id = NULL, target_redirect_id = $3, anonymous = $5
                  WHERE r.domain_id = $1 AND r.path = $2
                    AND r.target_site_id = $4%s',
                routes_schema,
                routes_table,
                CASE WHEN routes_key IS NULL
                     THEN ' AND $6 IS NULL'
                     ELSE format(' AND r.%I = $6', routes_key)
                END
            );

            EXECUTE query USING domain_id, entry_path, target_id,
                install_route_bindings.site_id, entry_anonymous, key_value;
            GET DIAGNOSTICS repointed_now = ROW_COUNT;
        END IF;

        IF inserted > 0 THEN
            installed := installed || jsonb_build_array(entry_path);
        ELSIF repointed_now > 0 THEN
            repointed := repointed || jsonb_build_array(entry_path);
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
        'repointed', repointed,
        'skipped', skipped,
        'serving_site_field', routes_serving_site_key,
        'serving_site_backfilled', stamped
    );
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

COMMENT ON FUNCTION function_resolution.install_route_bindings(uuid, text, text, uuid, jsonb, uuid) IS 'Install a set of route bindings — a JSON array of {path, target, …} entries, each NAMING its target kind ("function" with a task_identifier, "service" with a service_id, or "redirect" with a to_path) — onto one site as ordinary route rows, at ONE scope for ONE entity. The scope and ownership key are read from the named sites plane''s own site_surface_module registration, located along the caller''s frames (nearest first) so a shared serving plane hosted by an outer frame''s database resolves for the tenant consuming it — never a caller-supplied or generated literal — and that one (scope, key) then names the routes plane (app_scope.routing_tables), pins the site, route and service reads, starts function_resolution.resolve''s frame walk, and stamps every inserted row; a service target is proved to exist in the same-scope resources plane the routes plane''s registration records, which is the plane target_service_id FKs. A redirect binding writes a row in the routes plane''s own redirects table (same-host unless to_host is given, 302 unless status_code is given) and is the one kind allowed to repoint an existing route: the root guard''s placeholder still targeting the site being installed onto. Idempotent per (domain_id, path); raises on a malformed document, an unknown or ambiguous target kind, an unregistered plane, a scope with no routes plane, a missing entity key, an unknown site, an unrouted site, a scope with no resources plane, an unresolvable service, or an unpublished task.';

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

    -- Two shapes only: a page ({path, task_identifier}, no target kind — it is
    -- always a function), or a redirect ({path, target: 'redirect', to_path}) a
    -- host given over to the page set uses to send its root at sign-in. A
    -- service binding, or a page that names a kind, is a broken preset.
    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(install_mantra.bindings) AS b
        WHERE jsonb_typeof(b) <> 'object'
           OR coalesce(b ->> 'path', '') = ''
           OR CASE b ->> 'target'
                WHEN 'redirect' THEN coalesce(b ->> 'to_path', '') = '' OR b ? 'task_identifier'
                ELSE coalesce(b ->> 'task_identifier', '') = '' OR b ? 'target'
              END
    ) THEN
        RAISE EXCEPTION 'MANTRA_BINDINGS_INVALID: every binding must carry a non-empty path and either a task_identifier with no target kind, or target "redirect" with a to_path'
            USING ERRCODE = 'FR060';
    END IF;

    SELECT jsonb_agg(
        CASE WHEN b ->> 'target' = 'redirect' THEN b
             ELSE b || jsonb_build_object('target', 'function')
        END
    )
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

COMMENT ON FUNCTION function_resolution.install_mantra(uuid, regclass, uuid, jsonb, uuid) IS 'Install the Mantra page set (a JSON array of {path, task_identifier}, which the generated verb reads from the content_presets catalog at kind ''route_bindings'') onto one site as ordinary function-target routes. The sites plane arrives by reference as a regclass, so a generated caller never spells a schema name in a bare string literal the platform export''s AST rename cannot follow. A thin wrapper holding the Mantra document contract — every entry names a task and no target kind, or is a {target: "redirect", to_path} entry sending a path (a dedicated host''s root) at one of the pages — over function_resolution.install_route_bindings, which owns the one-scope install: scope and ownership key read from the sites plane''s own registration, the routes plane from app_scope.routing_tables, resolution at that same (scope, entity), idempotent per (domain_id, path).';

CREATE FUNCTION function_resolution.schedule_defer_reason(
  sched app_jobs.scheduled_jobs
) RETURNS text AS $EOFCODE$
DECLARE
    scope text := 'database';
    task_identifier text := sched.task_identifier;
BEGIN
    IF sched.key LIKE 'function_schedule:%' THEN
        RETURN NULL;
    END IF;

    IF json_typeof(sched.payload -> 'scope') = 'string' THEN
        scope := sched.payload ->> 'scope';
    END IF;

    IF json_typeof(sched.payload -> 'execution_id') = 'string'
       AND json_typeof(sched.payload -> 'node_name') = 'string'
       AND json_typeof(sched.payload -> 'node_type') = 'string'
       AND sched.payload -> 'inputs' IS NOT NULL THEN
        task_identifier := sched.payload ->> 'node_type';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM function_resolution.resolve(
            sched.database_id,
            scope,
            sched.entity_id,
            task_identifier,
            false
        )
    ) THEN
        RETURN NULL;
    END IF;

    RETURN format(
        'FUNCTION_NOT_REGISTERED: no function definition for task_identifier "%s" in the scope chain starting at scope "%s" (database_id=%s)',
        task_identifier, scope, sched.database_id
    );
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION function_resolution.schedule_defer_reason(app_jobs.scheduled_jobs) IS 'Registration check for function_resolution.fire_due_scheduled_jobs: NULL when the job a schedule spawns resolves to a function definition, else the reason it does not yet.';

CREATE FUNCTION function_resolution.fire_due_scheduled_jobs(
  batch_size int DEFAULT 200,
  defer_for interval DEFAULT '1 minute'
) RETURNS jsonb AS $EOFCODE$
DECLARE
  sched app_jobs.scheduled_jobs;
  outcome text;
  defer_reason text;
  check_failed boolean;
  fired int := 0;
  skipped int := 0;
  failed int := 0;
  deferred int := 0;
  error_message text;
  error_detail text;
BEGIN
  IF defer_for IS NULL OR defer_for <= interval '0' THEN
    PERFORM errors.raise_error('SCHEDULE_DEFER_INTERVAL_INVALID', jsonb_build_object('defer_for', defer_for), 'public');
  END IF;

  FOR sched IN
  SELECT
    *
  FROM
    app_jobs.claim_due_scheduled_jobs(batch_size)
    LOOP
      defer_reason := NULL;
      check_failed := false;
      BEGIN
        defer_reason := function_resolution.schedule_defer_reason(sched);
      EXCEPTION
        WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS error_message = MESSAGE_TEXT,
          error_detail = PG_EXCEPTION_DETAIL;
          check_failed := true;
      END;

      IF check_failed THEN
        PERFORM app_jobs.record_scheduled_job_failure(sched, error_message, error_detail);
        failed := failed + 1;
      ELSIF defer_reason IS NOT NULL THEN
        PERFORM app_jobs.defer_scheduled_job(sched, defer_reason, defer_for);
        deferred := deferred + 1;
      ELSE
        outcome := app_jobs.fire_scheduled_job(sched);
        IF outcome = 'fired' THEN
          fired := fired + 1;
        ELSIF outcome = 'skipped' THEN
          skipped := skipped + 1;
        ELSE
          failed := failed + 1;
        END IF;
      END IF;
    END LOOP;

  RETURN jsonb_build_object('fired', fired, 'skipped', skipped, 'failed', failed, 'deferred', deferred, 'processed', fired + skipped + failed + deferred);
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION function_resolution.routing_planes() RETURNS TABLE (
  database_id uuid,
  schema_name text,
  resolver_function_name text
) AS $EOFCODE$
    SELECT
        rm.database_id,
        s.schema_name::text,
        rm.resolver_function_name
    FROM metaschema_modules_public.route_module AS rm
    LEFT JOIN metaschema_public.schema AS s ON s.id = rm.schema_id
    WHERE rm.scope = 'database'
    ORDER BY rm.database_id
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.routing_planes() FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.database_standing(
  database_id uuid
) RETURNS TABLE (
  suspended_at timestamptz,
  suspended_reason text
) AS $EOFCODE$
    SELECT d.suspended_at, d.suspended_reason
    FROM metaschema_public.database AS d
    WHERE d.id = database_standing.database_id
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.database_standing(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.agent_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  entity_field text,
  has_plans boolean,
  has_agents boolean,
  has_runs boolean,
  public_schema text,
  private_schema text,
  thread_table_name text,
  message_table_name text,
  task_table_name text,
  plan_table_name text,
  agent_table_name text,
  persona_table_name text,
  resource_table_name text,
  run_table_name text,
  event_table_name text,
  workspace_table_name text,
  settle_run_cost_function_name text
) AS $EOFCODE$
SELECT
    am.database_id,
    (am.database_id = app_scope.platform_database_id()) AS platform_owned,
    am.scope,
    am.entity_field,
    am.has_plans,
    am.has_agents,
    am.has_runs,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    thread_t.name AS thread_table_name,
    message_t.name AS message_table_name,
    task_t.name AS task_table_name,
    plan_t.name AS plan_table_name,
    agent_t.name AS agent_table_name,
    persona_t.name AS persona_table_name,
    resource_t.name AS resource_table_name,
    run_t.name AS run_table_name,
    event_t.name AS event_table_name,
    workspace_t.name AS workspace_table_name,
    am.settle_run_cost_function_name
FROM metaschema_modules_public.agent_module AS am
    LEFT JOIN metaschema_public.schema ps ON ps.id = am.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = am.private_schema_id
    LEFT JOIN metaschema_public.table thread_t
    ON thread_t.id = am.thread_table_id AND am.thread_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table message_t
    ON message_t.id = am.message_table_id AND am.message_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table task_t
    ON task_t.id = am.task_table_id AND am.task_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table plan_t
    ON plan_t.id = am.plan_table_id
    LEFT JOIN metaschema_public.table agent_t
    ON agent_t.id = am.agent_table_id
    LEFT JOIN metaschema_public.table persona_t
    ON persona_t.id = am.persona_table_id
    LEFT JOIN metaschema_public.table resource_t
    ON resource_t.id = am.resource_table_id
    LEFT JOIN metaschema_public.table run_t
    ON run_t.id = am.run_table_id
    LEFT JOIN metaschema_public.table event_t
    ON event_t.id = am.event_table_id
    LEFT JOIN metaschema_public.table workspace_t
    ON workspace_t.id = am.workspace_table_id
WHERE am.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.agent_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.billing_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  public_schema text,
  private_schema text,
  record_usage_function text,
  meters_table_name text,
  grant_meter_credits_function text,
  credit_packs_table_name text,
  sweep_expired_subscriptions_function text,
  rollup_usage_summary_function text
) AS $EOFCODE$
SELECT
    bm.database_id,
    (bm.database_id = app_scope.platform_database_id()) AS platform_owned,
    'app'::text AS scope,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    bm.record_usage_function,
    bm.meters_table_name,
    bm.grant_meter_credits_function,
    bm.credit_packs_table_name,
    bm.sweep_expired_subscriptions_function,
    bm.rollup_usage_summary_function
FROM metaschema_modules_public.billing_module AS bm
    LEFT JOIN metaschema_public.schema ps ON ps.id = bm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = bm.private_schema_id
WHERE bm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.billing_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.billing_provider_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  provider text,
  private_schema text,
  list_pending_usage_sync_function text,
  mark_usage_synced_function text,
  get_billing_customer_function text,
  upsert_billing_customer_function text,
  get_billing_product_function text,
  upsert_billing_product_function text,
  get_billing_price_function text,
  upsert_billing_price_function text,
  get_billing_subscription_function text,
  upsert_billing_subscription_function text,
  sweep_overdue_subscriptions_function text,
  get_active_plan_pricing_function text,
  get_fallback_free_plan_function text,
  activate_plan_subscription_function text,
  get_active_plan_subscription_function text,
  get_billing_subscription_by_entity_function text,
  get_billing_subscription_by_external_id_function text,
  get_plan_pricing_by_external_price_function text,
  reserve_billing_operation_function text,
  finish_billing_operation_function text,
  apply_provider_observation_function text,
  list_due_reconciliations_function text,
  prepare_scheduled_change_function text,
  clear_scheduled_change_function text,
  get_billing_provider_state_function text,
  record_billing_health_function text,
  record_billing_connection_function text,
  bind_checkout_session_function text,
  upsert_invoice_function text,
  record_refund_function text,
  record_dispute_function text,
  billing_customers_table_name text,
  billing_prices_table_name text,
  billing_subscriptions_table_name text,
  customers_schema text,
  customers_table text,
  subscriptions_schema text,
  subscriptions_table text,
  products_schema text,
  products_table text,
  prices_schema text,
  prices_table text,
  invoices_schema text,
  invoices_table text,
  operations_schema text,
  operations_table text,
  provider_state_schema text,
  provider_state_table text,
  health_schema text,
  health_table text,
  meters_schema text,
  meters_table text,
  credit_packs_schema text,
  credit_packs_table text,
  plan_subscriptions_schema text,
  plan_subscriptions_table text,
  ledger_schema text,
  ledger_table text,
  balances_schema text,
  balances_table text,
  meter_credits_schema text,
  meter_credits_table text,
  plans_schema text,
  plans_table text,
  plan_pricing_schema text,
  plan_pricing_table text,
  plan_limits_schema text,
  plan_limits_table text,
  plan_meter_limits_schema text,
  plan_meter_limits_table text,
  plan_caps_schema text,
  plan_caps_table text,
  limits_schema text,
  limits_table text,
  limit_defaults_schema text,
  limit_defaults_table text,
  users_schema text,
  users_table text
) AS $EOFCODE$
SELECT
    bpm.database_id,
    (bpm.database_id = app_scope.platform_database_id()) AS platform_owned,
    'app'::text AS scope,
    bpm.provider,
    pvs.schema_name AS private_schema,
    bpm.list_pending_usage_sync_function,
    bpm.mark_usage_synced_function,
    bpm.get_billing_customer_function,
    bpm.upsert_billing_customer_function,
    bpm.get_billing_product_function,
    bpm.upsert_billing_product_function,
    bpm.get_billing_price_function,
    bpm.upsert_billing_price_function,
    bpm.get_billing_subscription_function,
    bpm.upsert_billing_subscription_function,
    bpm.sweep_overdue_subscriptions_function,
    bpm.get_active_plan_pricing_function,
    bpm.get_fallback_free_plan_function,
    bpm.activate_plan_subscription_function,
    bpm.get_active_plan_subscription_function,
    bpm.get_billing_subscription_by_entity_function,
    bpm.get_billing_subscription_by_external_id_function,
    bpm.get_plan_pricing_by_external_price_function,
    bpm.reserve_billing_operation_function,
    bpm.finish_billing_operation_function,
    bpm.apply_provider_observation_function,
    bpm.list_due_reconciliations_function,
    bpm.prepare_scheduled_change_function,
    bpm.clear_scheduled_change_function,
    bpm.get_billing_provider_state_function,
    bpm.record_billing_health_function,
    bpm.record_billing_connection_function,
    bpm.bind_checkout_session_function,
    bpm.upsert_invoice_function,
    bpm.record_refund_function,
    bpm.record_dispute_function,
    bpm.billing_customers_table_name,
    bpm.billing_prices_table_name,
    bpm.billing_subscriptions_table_name,
    s_customers.schema_name AS customers_schema,
    t_customers.name AS customers_table,
    s_subscriptions.schema_name AS subscriptions_schema,
    t_subscriptions.name AS subscriptions_table,
    s_products.schema_name AS products_schema,
    t_products.name AS products_table,
    s_prices.schema_name AS prices_schema,
    t_prices.name AS prices_table,
    s_invoices.schema_name AS invoices_schema,
    t_invoices.name AS invoices_table,
    s_operations.schema_name AS operations_schema,
    t_operations.name AS operations_table,
    s_providerState.schema_name AS provider_state_schema,
    t_providerState.name AS provider_state_table,
    s_health.schema_name AS health_schema,
    t_health.name AS health_table,
    s_meters.schema_name AS meters_schema,
    t_meters.name AS meters_table,
    s_creditPacks.schema_name AS credit_packs_schema,
    t_creditPacks.name AS credit_packs_table,
    s_planSubscriptions.schema_name AS plan_subscriptions_schema,
    t_planSubscriptions.name AS plan_subscriptions_table,
    s_ledger.schema_name AS ledger_schema,
    t_ledger.name AS ledger_table,
    s_balances.schema_name AS balances_schema,
    t_balances.name AS balances_table,
    s_meterCredits.schema_name AS meter_credits_schema,
    t_meterCredits.name AS meter_credits_table,
    s_plans.schema_name AS plans_schema,
    t_plans.name AS plans_table,
    s_planPricing.schema_name AS plan_pricing_schema,
    t_planPricing.name AS plan_pricing_table,
    s_planLimits.schema_name AS plan_limits_schema,
    t_planLimits.name AS plan_limits_table,
    s_planMeterLimits.schema_name AS plan_meter_limits_schema,
    t_planMeterLimits.name AS plan_meter_limits_table,
    s_planCaps.schema_name AS plan_caps_schema,
    t_planCaps.name AS plan_caps_table,
    s_limits.schema_name AS limits_schema,
    t_limits.name AS limits_table,
    s_limitDefaults.schema_name AS limit_defaults_schema,
    t_limitDefaults.name AS limit_defaults_table,
    s_users.schema_name AS users_schema,
    t_users.name AS users_table
FROM metaschema_modules_public.billing_provider_module AS bpm
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = bpm.private_schema_id
    LEFT JOIN metaschema_modules_public.billing_module bm ON bm.database_id = bpm.database_id
    LEFT JOIN metaschema_modules_public.plans_module pm ON pm.database_id = bpm.database_id
    LEFT JOIN metaschema_modules_public.limits_module lm
    ON lm.database_id = bpm.database_id AND lm.scope = 'app'
    LEFT JOIN metaschema_modules_public.user_auth_module uam ON uam.database_id = bpm.database_id
    LEFT JOIN metaschema_public."table" t_customers ON t_customers.id = bpm.billing_customers_table_id
    LEFT JOIN metaschema_public.schema s_customers ON s_customers.id = t_customers.schema_id
    LEFT JOIN metaschema_public."table" t_subscriptions ON t_subscriptions.id = bpm.billing_subscriptions_table_id
    LEFT JOIN metaschema_public.schema s_subscriptions ON s_subscriptions.id = t_subscriptions.schema_id
    LEFT JOIN metaschema_public."table" t_products ON t_products.id = bpm.billing_products_table_id
    LEFT JOIN metaschema_public.schema s_products ON s_products.id = t_products.schema_id
    LEFT JOIN metaschema_public."table" t_prices ON t_prices.id = bpm.billing_prices_table_id
    LEFT JOIN metaschema_public.schema s_prices ON s_prices.id = t_prices.schema_id
    LEFT JOIN metaschema_public."table" t_invoices ON t_invoices.id = bpm.billing_invoices_table_id
    LEFT JOIN metaschema_public.schema s_invoices ON s_invoices.id = t_invoices.schema_id
    LEFT JOIN metaschema_public."table" t_operations ON t_operations.id = bpm.billing_operations_table_id
    LEFT JOIN metaschema_public.schema s_operations ON s_operations.id = t_operations.schema_id
    LEFT JOIN metaschema_public."table" t_providerState ON t_providerState.id = bpm.billing_provider_state_table_id
    LEFT JOIN metaschema_public.schema s_providerState ON s_providerState.id = t_providerState.schema_id
    LEFT JOIN metaschema_public."table" t_health ON t_health.id = bpm.billing_health_table_id
    LEFT JOIN metaschema_public.schema s_health ON s_health.id = t_health.schema_id
    LEFT JOIN metaschema_public."table" t_meters ON t_meters.id = bm.meters_table_id
    LEFT JOIN metaschema_public.schema s_meters ON s_meters.id = t_meters.schema_id
    LEFT JOIN metaschema_public."table" t_creditPacks ON t_creditPacks.id = bm.credit_packs_table_id
    LEFT JOIN metaschema_public.schema s_creditPacks ON s_creditPacks.id = t_creditPacks.schema_id
    LEFT JOIN metaschema_public."table" t_planSubscriptions ON t_planSubscriptions.id = bm.plan_subscriptions_table_id
    LEFT JOIN metaschema_public.schema s_planSubscriptions ON s_planSubscriptions.id = t_planSubscriptions.schema_id
    LEFT JOIN metaschema_public."table" t_ledger ON t_ledger.id = bm.ledger_table_id
    LEFT JOIN metaschema_public.schema s_ledger ON s_ledger.id = t_ledger.schema_id
    LEFT JOIN metaschema_public."table" t_balances ON t_balances.id = bm.balances_table_id
    LEFT JOIN metaschema_public.schema s_balances ON s_balances.id = t_balances.schema_id
    LEFT JOIN metaschema_public."table" t_meterCredits ON t_meterCredits.id = bm.meter_credits_table_id
    LEFT JOIN metaschema_public.schema s_meterCredits ON s_meterCredits.id = t_meterCredits.schema_id
    LEFT JOIN metaschema_public."table" t_plans ON t_plans.id = pm.plans_table_id
    LEFT JOIN metaschema_public.schema s_plans ON s_plans.id = t_plans.schema_id
    LEFT JOIN metaschema_public."table" t_planPricing ON t_planPricing.id = pm.plan_pricing_table_id
    LEFT JOIN metaschema_public.schema s_planPricing ON s_planPricing.id = t_planPricing.schema_id
    LEFT JOIN metaschema_public."table" t_planLimits ON t_planLimits.id = pm.plan_limits_table_id
    LEFT JOIN metaschema_public.schema s_planLimits ON s_planLimits.id = t_planLimits.schema_id
    LEFT JOIN metaschema_public."table" t_planMeterLimits ON t_planMeterLimits.id = pm.plan_meter_limits_table_id
    LEFT JOIN metaschema_public.schema s_planMeterLimits ON s_planMeterLimits.id = t_planMeterLimits.schema_id
    LEFT JOIN metaschema_public."table" t_planCaps ON t_planCaps.id = pm.plan_caps_table_id
    LEFT JOIN metaschema_public.schema s_planCaps ON s_planCaps.id = t_planCaps.schema_id
    LEFT JOIN metaschema_public."table" t_limits ON t_limits.id = lm.table_id
    LEFT JOIN metaschema_public.schema s_limits ON s_limits.id = t_limits.schema_id
    LEFT JOIN metaschema_public."table" t_limitDefaults ON t_limitDefaults.id = lm.default_table_id
    LEFT JOIN metaschema_public.schema s_limitDefaults ON s_limitDefaults.id = t_limitDefaults.schema_id
    LEFT JOIN metaschema_public."table" t_users ON t_users.id = uam.users_table_id
    LEFT JOIN metaschema_public.schema s_users ON s_users.id = t_users.schema_id
WHERE bpm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.billing_provider_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.cluster_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  entity_field text,
  prefix text,
  host_database_id uuid,
  public_schema text,
  private_schema text,
  clusters_table_name text,
  cluster_events_table_name text,
  database_servers_table_name text,
  physical_databases_table_name text,
  database_placements_table_name text
) AS $EOFCODE$
SELECT
    cm.database_id,
    (cm.database_id = app_scope.platform_database_id()) AS platform_owned,
    cm.scope,
    cm.entity_field,
    cm.prefix,
    cm.database_id AS host_database_id,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    clusters_t.name AS clusters_table_name,
    events_t.name AS cluster_events_table_name,
    servers_t.name AS database_servers_table_name,
    pdbs_t.name AS physical_databases_table_name,
    placements_t.name AS database_placements_table_name
FROM metaschema_modules_public.cluster_module AS cm
    LEFT JOIN metaschema_public.schema ps ON ps.id = cm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = cm.private_schema_id
    LEFT JOIN metaschema_public.table clusters_t
    ON clusters_t.id = cm.clusters_table_id AND cm.clusters_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table events_t
    ON events_t.id = cm.cluster_events_table_id AND cm.cluster_events_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table servers_t
    ON servers_t.id = cm.database_servers_table_id AND cm.database_servers_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table pdbs_t
    ON pdbs_t.id = cm.physical_databases_table_id AND cm.physical_databases_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table placements_t
    ON placements_t.id = cm.database_placements_table_id AND cm.database_placements_table_id <> uuid_nil()
WHERE ($1 IS NULL OR cm.database_id = $1)
  AND ($2 IS NULL OR cm.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.cluster_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.compute_log_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  compute_log_table_name text,
  usage_summary_table_name text,
  rollup_function_name text,
  logs_per_database boolean,
  entity_field text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    clm.database_id,
    (clm.database_id = app_scope.platform_database_id()) AS platform_owned,
    clm.scope,
    clm.compute_log_table_name,
    clm.usage_summary_table_name,
    clm.rollup_function_name,
    EXISTS (SELECT 1 FROM metaschema_public.field AS f WHERE f.table_id = clm.compute_log_table_id AND f.name = 'database_id') AS logs_per_database,
    clm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.compute_log_module AS clm
    LEFT JOIN metaschema_public.schema ps ON ps.id = clm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = clm.private_schema_id
WHERE clm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.compute_log_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.database_settings_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  entity_field text,
  public_schema text,
  database_settings_table_name text,
  rls_settings_table_name text
) AS $EOFCODE$
SELECT
    dsm.database_id,
    (dsm.database_id = app_scope.platform_database_id()) AS platform_owned,
    dsm.scope,
    dsm.entity_field,
    ps.schema_name AS public_schema,
    settings_t.name AS database_settings_table_name,
    rls_t.name AS rls_settings_table_name
FROM metaschema_modules_public.database_settings_module AS dsm
    LEFT JOIN metaschema_public.schema ps ON ps.id = dsm.schema_id
    LEFT JOIN metaschema_public.table settings_t
    ON settings_t.id = dsm.database_settings_table_id
    AND dsm.database_settings_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table rls_t
    ON rls_t.id = dsm.rls_settings_table_id AND dsm.rls_settings_table_id <> uuid_nil()
WHERE dsm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.database_settings_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.db_usage_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  collect_db_table_stats_function text,
  collect_db_query_stats_function text,
  rollup_db_table_stats_usage_summary_function text,
  rollup_db_query_stats_usage_summary_function text,
  private_schema text
) AS $EOFCODE$
SELECT
    dum.database_id,
    (dum.database_id = app_scope.platform_database_id()) AS platform_owned,
    dum.collect_db_table_stats_function,
    dum.collect_db_query_stats_function,
    dum.rollup_db_table_stats_usage_summary_function,
    dum.rollup_db_query_stats_usage_summary_function,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.db_usage_module AS dum
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = dum.private_schema_id
WHERE dum.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.db_usage_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.domain_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  domains_table_name text,
  domain_verifications_table_name text,
  domain_events_table_name text,
  managed_domains_table_name text,
  entity_field text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    dm.database_id,
    (dm.database_id = app_scope.platform_database_id()) AS platform_owned,
    dm.scope,
    dm.domains_table_name,
    dm.domain_verifications_table_name,
    dm.domain_events_table_name,
    dm.managed_domains_table_name,
    dm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.domain_module AS dm
    LEFT JOIN metaschema_public.schema ps ON ps.id = dm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = dm.private_schema_id
WHERE ($1 IS NULL OR dm.database_id = $1)
  AND ($2 IS NULL OR dm.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.domain_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.email_sender_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  entity_field text,
  public_schema text,
  provider_accounts_table_name text,
  identities_table_name text,
  site_identities_table_name text
) AS $EOFCODE$
SELECT
    esm.database_id,
    (esm.database_id = app_scope.platform_database_id()) AS platform_owned,
    esm.scope,
    esm.entity_field,
    ps.schema_name AS public_schema,
    accounts_t.name AS provider_accounts_table_name,
    identities_t.name AS identities_table_name,
    site_identities_t.name AS site_identities_table_name
FROM metaschema_modules_public.email_sender_module AS esm
    LEFT JOIN metaschema_public.schema ps ON ps.id = esm.schema_id
    LEFT JOIN metaschema_public.table accounts_t
    ON accounts_t.id = esm.email_provider_accounts_table_id
   AND esm.email_provider_accounts_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table identities_t
    ON identities_t.id = esm.email_identities_table_id
   AND esm.email_identities_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table site_identities_t
    ON site_identities_t.id = esm.email_site_identities_table_id
WHERE esm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.email_sender_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.emails_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  public_schema text,
  emails_table_name text
) AS $EOFCODE$
SELECT
    em.database_id,
    (em.database_id = app_scope.platform_database_id()) AS platform_owned,
    ps.schema_name AS public_schema,
    emails_t.name AS emails_table_name
FROM metaschema_modules_public.emails_module AS em
    LEFT JOIN metaschema_public.schema ps ON ps.id = em.schema_id
    LEFT JOIN metaschema_public.table emails_t
    ON emails_t.id = em.table_id AND em.table_id <> uuid_nil()
WHERE em.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.emails_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.events_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  private_schema text,
  record_event text,
  expire_grants text
) AS $EOFCODE$
SELECT
    em.database_id,
    (em.database_id = app_scope.platform_database_id()) AS platform_owned,
    em.scope,
    pvs.schema_name AS private_schema,
    em.record_event,
    em.expire_grants
FROM metaschema_modules_public.events_module AS em
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = em.private_schema_id
WHERE em.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.events_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.file_ref_field_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  id uuid,
  storage_module_id uuid,
  schema_name text,
  table_name text,
  field_name text,
  bucket_key text,
  bucket_tags text[],
  is_public boolean,
  enforce_fk boolean
) AS $EOFCODE$
SELECT
    frf.database_id,
    (frf.database_id = app_scope.platform_database_id()) AS platform_owned,
    frf.id,
    frf.storage_module_id,
    s.schema_name,
    t.name AS table_name,
    f.name AS field_name,
    frf.bucket_key,
    frf.bucket_tags::text[] AS bucket_tags,
    frf.is_public,
    frf.enforce_fk
FROM metaschema_modules_public.file_ref_field AS frf
    JOIN metaschema_public.field f ON f.id = frf.field_id
    JOIN metaschema_public.table t ON t.id = frf.table_id
    JOIN metaschema_public.schema s ON s.id = t.schema_id
WHERE frf.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.file_ref_field_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.function_deployment_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  entity_field text,
  deployments_table_name text,
  deployment_events_table_name text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    fdm.database_id,
    (fdm.database_id = app_scope.platform_database_id()) AS platform_owned,
    fdm.scope,
    fdm.entity_field,
    fdm.deployments_table_name,
    fdm.deployment_events_table_name,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.function_deployment_module AS fdm
    LEFT JOIN metaschema_public.schema ps ON ps.id = fdm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = fdm.private_schema_id
WHERE ($1 IS NULL OR fdm.database_id = $1)
  AND ($2 IS NULL OR fdm.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.function_deployment_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.function_invocation_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  invocations_table_name text,
  execution_logs_table_name text,
  attempts_table_name text,
  entity_field text,
  public_schema text,
  private_schema text,
  id uuid
) AS $EOFCODE$
SELECT
    im.database_id,
    (im.database_id = app_scope.platform_database_id()) AS platform_owned,
    im.scope,
    im.invocations_table_name,
    im.execution_logs_table_name,
    im.attempts_table_name,
    im.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    im.id
FROM metaschema_modules_public.function_invocation_module AS im
    LEFT JOIN metaschema_public.schema ps ON ps.id = im.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = im.private_schema_id
WHERE ($1 IS NULL OR im.database_id = $1)
  AND ($2 IS NULL OR im.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.function_invocation_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.function_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  definitions_table_name text,
  entity_field text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    fm.database_id,
    (fm.database_id = app_scope.platform_database_id()) AS platform_owned,
    fm.scope,
    fm.definitions_table_name,
    fm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.function_module AS fm
    LEFT JOIN metaschema_public.schema ps ON ps.id = fm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = fm.private_schema_id
WHERE ($1 IS NULL OR fm.database_id = $1)
  AND ($2 IS NULL OR fm.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.function_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.graph_execution_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  prefix text,
  node_states_table_name text,
  executions_table_name text,
  outputs_table_name text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    gem.database_id,
    (gem.database_id = app_scope.platform_database_id()) AS platform_owned,
    gem.scope,
    gem.prefix,
    node_states_t.name AS node_states_table_name,
    executions_t.name AS executions_table_name,
    outputs_t.name AS outputs_table_name,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.graph_execution_module AS gem
    LEFT JOIN metaschema_public.schema ps ON ps.id = gem.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = gem.private_schema_id
    LEFT JOIN metaschema_public.table node_states_t ON node_states_t.id = gem.node_states_table_id
    LEFT JOIN metaschema_public.table executions_t ON executions_t.id = gem.executions_table_id
    LEFT JOIN metaschema_public.table outputs_t ON outputs_t.id = gem.outputs_table_id
WHERE ($1 IS NULL OR gem.database_id = $1)
  AND ($2 IS NULL OR gem.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.graph_execution_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.graph_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  prefix text,
  entity_field text,
  graphs_table_name text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    gm.database_id,
    (gm.database_id = app_scope.platform_database_id()) AS platform_owned,
    gm.scope,
    gm.prefix,
    gm.entity_field,
    graphs_t.name AS graphs_table_name,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.graph_module AS gm
    LEFT JOIN metaschema_public.schema ps ON ps.id = gm.public_schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = gm.private_schema_id
    LEFT JOIN metaschema_public.table graphs_t ON graphs_t.id = gm.graphs_table_id
WHERE ($1 IS NULL OR gm.database_id = $1)
  AND ($2 IS NULL OR gm.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.graph_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.identity_providers_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  entity_field text,
  public_schema text,
  private_schema text,
  providers_table_name text
) AS $EOFCODE$
SELECT
    ipm.database_id,
    (ipm.database_id = app_scope.platform_database_id()) AS platform_owned,
    ipm.scope,
    ipm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    providers_t.name AS providers_table_name
FROM metaschema_modules_public.identity_providers_module AS ipm
    LEFT JOIN metaschema_public.schema ps ON ps.id = ipm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = ipm.private_schema_id
    LEFT JOIN metaschema_public.table providers_t
    ON providers_t.id = ipm.table_id AND ipm.table_id <> uuid_nil()
WHERE ipm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.identity_providers_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.image_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  prefix text,
  entity_field text,
  images_table_name text,
  image_grants_table_name text,
  registries_table_name text,
  registry_grants_table_name text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    imgm.database_id,
    (imgm.database_id = app_scope.platform_database_id()) AS platform_owned,
    imgm.scope,
    imgm.prefix,
    imgm.entity_field,
    imgm.images_table_name,
    imgm.image_grants_table_name,
    imgm.registries_table_name,
    imgm.registry_grants_table_name,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.image_module AS imgm
    LEFT JOIN metaschema_public.schema ps ON ps.id = imgm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = imgm.private_schema_id
WHERE ($1 IS NULL OR imgm.database_id = $1)
  AND ($2 IS NULL OR imgm.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.image_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.inference_log_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  inference_log_table_name text,
  usage_summary_table_name text,
  rollup_function_name text,
  logs_per_database boolean,
  entity_field text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    ilm.database_id,
    (ilm.database_id = app_scope.platform_database_id()) AS platform_owned,
    ilm.scope,
    ilm.inference_log_table_name,
    ilm.usage_summary_table_name,
    ilm.rollup_function_name,
    EXISTS (SELECT 1 FROM metaschema_public.field AS f WHERE f.table_id = ilm.inference_log_table_id AND f.name = 'database_id') AS logs_per_database,
    ilm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.inference_log_module AS ilm
    LEFT JOIN metaschema_public.schema ps ON ps.id = ilm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = ilm.private_schema_id
WHERE ilm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.inference_log_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.infra_secrets_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
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
) AS $EOFCODE$
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
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.infra_secrets_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.internal_config_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  entity_field text,
  prefix text,
  config_table_name text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    icm.database_id,
    (icm.database_id = app_scope.platform_database_id()) AS platform_owned,
    icm.scope,
    icm.entity_field,
    icm.prefix,
    cfg_t.name AS config_table_name,
    pub_s.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.internal_config_module AS icm
    LEFT JOIN metaschema_public.table cfg_t ON cfg_t.id = icm.internal_config_table_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = icm.private_schema_id
    LEFT JOIN metaschema_public.schema pub_s ON pub_s.id = icm.schema_id
WHERE icm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.internal_config_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.internal_secrets_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  entity_field text,
  prefix text,
  secrets_table_name text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    ism.database_id,
    (ism.database_id = app_scope.platform_database_id()) AS platform_owned,
    ism.scope,
    ism.entity_field,
    ism.prefix,
    sec_t.name AS secrets_table_name,
    pub_s.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.internal_secrets_module AS ism
    LEFT JOIN metaschema_public.table sec_t ON sec_t.id = ism.internal_secrets_table_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = ism.private_schema_id
    LEFT JOIN metaschema_public.schema pub_s ON pub_s.id = ism.schema_id
WHERE ism.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.internal_secrets_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.machine_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  prefix text,
  entity_field text,
  machines_table_name text,
  machine_sessions_table_name text,
  machine_messages_table_name text,
  partition_interval text,
  retention text,
  premake int,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    mm.database_id,
    (mm.database_id = app_scope.platform_database_id()) AS platform_owned,
    mm.scope,
    mm.prefix,
    mm.entity_field,
    mm.machines_table_name,
    mm.machine_sessions_table_name,
    mm.machine_messages_table_name,
    mm.partition_interval,
    mm.retention,
    mm.premake,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.machine_module AS mm
    LEFT JOIN metaschema_public.schema ps ON ps.id = mm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = mm.private_schema_id
WHERE ($1 IS NULL OR mm.database_id = $1)
  AND ($2 IS NULL OR mm.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.machine_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.memberships_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  prefix text,
  entity_field text,
  memberships_table_name text,
  members_table_name text,
  grants_table_name text,
  actor_perm_check text,
  public_schema text,
  private_schema text,
  sprt_table_name text
) AS $EOFCODE$
SELECT
    mm.database_id,
    (mm.database_id = app_scope.platform_database_id()) AS platform_owned,
    mm.scope,
    mm.prefix,
    mm.entity_field,
    mm.memberships_table_name,
    mm.members_table_name,
    mm.grants_table_name,
    mm.actor_perm_check,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    sprt_t.name AS sprt_table_name
FROM metaschema_modules_public.memberships_module AS mm
    LEFT JOIN metaschema_public.schema ps ON ps.id = mm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = mm.private_schema_id
    LEFT JOIN metaschema_public.table sprt_t ON sprt_t.id = mm.sprt_table_id
WHERE mm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.memberships_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.namespace_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  namespaces_table_name text,
  namespace_events_table_name text,
  entity_field text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    nm.database_id,
    (nm.database_id = app_scope.platform_database_id()) AS platform_owned,
    nm.scope,
    nm.namespaces_table_name,
    nm.namespace_events_table_name,
    nm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.namespace_module AS nm
    LEFT JOIN metaschema_public.schema ps ON ps.id = nm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = nm.private_schema_id
WHERE ($1 IS NULL OR nm.database_id = $1)
  AND ($2 IS NULL OR nm.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.namespace_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.notifications_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  has_preferences boolean,
  has_digest_metadata boolean,
  public_schema text,
  private_schema text,
  notifications_table_name text,
  preferences_table_name text,
  suppressions_table_name text
) AS $EOFCODE$
SELECT
    nm.database_id,
    (nm.database_id = app_scope.platform_database_id()) AS platform_owned,
    nm.has_preferences,
    nm.has_digest_metadata,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    notifications_t.name AS notifications_table_name,
    preferences_t.name AS preferences_table_name,
    suppressions_t.name AS suppressions_table_name
FROM metaschema_modules_public.notifications_module AS nm
    LEFT JOIN metaschema_public.schema ps ON ps.id = nm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = nm.private_schema_id
    LEFT JOIN metaschema_public.table notifications_t
    ON notifications_t.id = nm.notifications_table_id
    LEFT JOIN metaschema_public.table preferences_t
    ON preferences_t.id = nm.preferences_table_id
    LEFT JOIN metaschema_public.table suppressions_t
    ON suppressions_t.id = nm.suppressions_table_id
WHERE nm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.notifications_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.oauth_requests_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  entity_field text,
  prefix text,
  private_schema text
) AS $EOFCODE$
SELECT
    orm.database_id,
    (orm.database_id = app_scope.platform_database_id()) AS platform_owned,
    orm.scope,
    orm.entity_field,
    orm.prefix,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.oauth_requests_module AS orm
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = orm.private_schema_id
WHERE orm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.oauth_requests_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.pages_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  public_schema text,
  page_published_function text
) AS $EOFCODE$
SELECT
    pm.database_id,
    (pm.database_id = app_scope.platform_database_id()) AS platform_owned,
    pm.scope,
    ps.schema_name AS public_schema,
    inflection_db.get_field_name(ARRAY[pm.prefix, 'page', 'published']) AS page_published_function
FROM metaschema_modules_public.pages_module AS pm
    LEFT JOIN metaschema_public.schema ps ON ps.id = pm.public_schema_id
WHERE pm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.pages_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.phone_numbers_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  public_schema text,
  phone_numbers_table_name text
) AS $EOFCODE$
SELECT
    pm.database_id,
    (pm.database_id = app_scope.platform_database_id()) AS platform_owned,
    ps.schema_name AS public_schema,
    phone_t.name AS phone_numbers_table_name
FROM metaschema_modules_public.phone_numbers_module AS pm
    LEFT JOIN metaschema_public.schema ps ON ps.id = pm.schema_id
    LEFT JOIN metaschema_public.table phone_t
    ON phone_t.id = pm.table_id AND pm.table_id <> uuid_nil()
WHERE pm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.phone_numbers_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.plans_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  public_schema text,
  plans_table_name text,
  plan_limits_table_name text,
  plan_pricing_table_name text
) AS $EOFCODE$
SELECT
    pm.database_id,
    (pm.database_id = app_scope.platform_database_id()) AS platform_owned,
    'app'::text AS scope,
    ps.schema_name AS public_schema,
    pm.plans_table_name,
    pm.plan_limits_table_name,
    pricing_t.name AS plan_pricing_table_name
FROM metaschema_modules_public.plans_module AS pm
    LEFT JOIN metaschema_public.schema ps ON ps.id = pm.schema_id
    LEFT JOIN metaschema_public.table pricing_t
    ON pricing_t.id = pm.plan_pricing_table_id
WHERE pm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.plans_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.principal_auth_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  sweep_expired_principals_function text,
  private_schema text
) AS $EOFCODE$
SELECT
    pam.database_id,
    (pam.database_id = app_scope.platform_database_id()) AS platform_owned,
    pam.sweep_expired_principals_function,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.principal_auth_module AS pam
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = pam.private_schema_id
WHERE pam.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.principal_auth_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.repository_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  prefix text,
  entity_field text,
  host_database_id uuid,
  repositories_table_name text,
  repository_events_table_name text,
  workflows_table_name text,
  builds_table_name text,
  build_steps_table_name text,
  proposals_table_name text,
  proposal_comments_table_name text,
  proposal_reactions_table_name text,
  proposal_reviews_table_name text,
  proposal_file_views_table_name text,
  repository_required_checks_table_name text,
  has_builds boolean,
  has_attachments boolean,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    rpm.database_id,
    (rpm.database_id = app_scope.platform_database_id()) AS platform_owned,
    rpm.scope,
    rpm.prefix,
    rpm.entity_field,
    rpm.database_id AS host_database_id,
    rpm.repositories_table_name,
    rpm.repository_events_table_name,
    rpm.workflows_table_name,
    rpm.builds_table_name,
    rpm.build_steps_table_name,
    rpm.proposals_table_name,
    rpm.proposal_comments_table_name,
    rpm.proposal_reactions_table_name,
    rpm.proposal_reviews_table_name,
    rpm.proposal_file_views_table_name,
    rpm.repository_required_checks_table_name,
    rpm.has_builds,
    rpm.has_attachments,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.repository_module AS rpm
    LEFT JOIN metaschema_public.schema ps ON ps.id = rpm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = rpm.private_schema_id
WHERE ($1 IS NULL OR rpm.database_id = $1)
  AND ($2 IS NULL OR rpm.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.repository_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.resource_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  resources_table_name text,
  resource_definitions_table_name text,
  resource_installations_table_name text,
  prefix text,
  resource_events_table_name text,
  resource_status_checks_table_name text,
  resource_usage_log_table_name text,
  resource_usage_summary_table_name text,
  resolved_requirements_view_name text,
  requirements_state_view_name text,
  entity_field text,
  public_schema text,
  private_schema text,
  registry_bindings_table_name text,
  builder_bindings_table_name text,
  rollup_resource_usage_summary_function text,
  resource_billing_rollup_function text
) AS $EOFCODE$
SELECT
    rm.database_id,
    (rm.database_id = app_scope.platform_database_id()) AS platform_owned,
    rm.scope,
    rm.resources_table_name,
    rm.resource_definitions_table_name,
    rm.resource_installations_table_name,
    rm.prefix,
    rm.resource_events_table_name,
    rm.resource_status_checks_table_name,
    rm.resource_usage_log_table_name,
    rm.resource_usage_summary_table_name,
    rm.resolved_requirements_view_name,
    rm.requirements_state_view_name,
    rm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    rm.registry_bindings_table_name,
    rm.builder_bindings_table_name,
    rm.rollup_resource_usage_summary_function,
    rm.resource_billing_rollup_function
FROM metaschema_modules_public.resource_module AS rm
    LEFT JOIN metaschema_public.schema ps ON ps.id = rm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = rm.private_schema_id
WHERE ($1 IS NULL OR rm.database_id = $1)
  AND ($2 IS NULL OR rm.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.resource_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.route_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
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
) AS $EOFCODE$
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
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.route_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.sessions_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  private_schema text,
  auth_settings_table_name text,
  sessions_table_name text,
  session_credentials_table_name text
) AS $EOFCODE$
SELECT
    sm.database_id,
    (sm.database_id = app_scope.platform_database_id()) AS platform_owned,
    pvs.schema_name AS private_schema,
    settings_t.name AS auth_settings_table_name,
    sessions_t.name AS sessions_table_name,
    credentials_t.name AS session_credentials_table_name
FROM metaschema_modules_public.sessions_module AS sm
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = sm.schema_id
    LEFT JOIN metaschema_public.table settings_t
    ON settings_t.id = sm.auth_settings_table_id AND sm.auth_settings_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table sessions_t ON sessions_t.id = sm.sessions_table_id
    LEFT JOIN metaschema_public.table credentials_t
    ON credentials_t.id = sm.session_credentials_table_id
WHERE sm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.sessions_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.site_surface_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
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
) AS $EOFCODE$
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
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.site_surface_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.storage_log_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  storage_log_table_name text,
  usage_summary_table_name text,
  rollup_function_name text,
  logs_per_database boolean,
  entity_field text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    slm.database_id,
    (slm.database_id = app_scope.platform_database_id()) AS platform_owned,
    slm.scope,
    slm.storage_log_table_name,
    slm.usage_summary_table_name,
    slm.rollup_function_name,
    EXISTS (SELECT 1 FROM metaschema_public.field AS f WHERE f.table_id = slm.storage_log_table_id AND f.name = 'database_id') AS logs_per_database,
    slm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.storage_log_module AS slm
    LEFT JOIN metaschema_public.schema ps ON ps.id = slm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = slm.private_schema_id
WHERE slm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.storage_log_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.storage_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  buckets_table_name text,
  files_table_name text,
  allowed_origins text[],
  public_schema text,
  private_schema text,
  endpoint text,
  provider text,
  region text,
  public_url_prefix text,
  connection_overrides text[],
  id uuid,
  entity_field text,
  buckets_table_id uuid,
  entity_table_id uuid,
  buckets_schema text,
  buckets_table text,
  files_schema text,
  files_table text,
  upload_url_expiry_seconds int,
  download_url_expiry_seconds int,
  default_max_file_size bigint,
  max_filename_length int,
  cache_ttl_seconds int,
  max_bulk_files int,
  max_bulk_total_size bigint,
  has_path_shares boolean,
  has_versioning boolean,
  has_content_hash boolean,
  has_confirm_upload boolean,
  entity_schema text,
  entity_table text
) AS $EOFCODE$
SELECT
    sm.database_id,
    (sm.database_id = app_scope.platform_database_id()) AS platform_owned,
    sm.scope,
    sm.buckets_table_name,
    sm.files_table_name,
    sm.allowed_origins,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    psm.endpoint AS endpoint,
    psm.provider AS provider,
    psm.region AS region,
    coalesce(sm.public_url_prefix, psm.public_url_prefix) AS public_url_prefix,
    array_remove(ARRAY[
      CASE WHEN sm.endpoint IS DISTINCT FROM psm.endpoint AND sm.endpoint IS NOT NULL THEN 'endpoint' END,
    CASE WHEN sm.provider IS DISTINCT FROM psm.provider AND sm.provider IS NOT NULL THEN 'provider' END,
    CASE WHEN sm.region IS DISTINCT FROM psm.region AND sm.region IS NOT NULL THEN 'region' END
    ], NULL) AS connection_overrides,
    sm.id,
    sm.entity_field,
    sm.buckets_table_id,
    sm.entity_table_id,
    bs.schema_name AS buckets_schema,
    bt.name AS buckets_table,
    fs.schema_name AS files_schema,
    ft.name AS files_table,
    sm.upload_url_expiry_seconds,
    sm.download_url_expiry_seconds,
    sm.default_max_file_size,
    sm.max_filename_length,
    sm.cache_ttl_seconds,
    sm.max_bulk_files,
    sm.max_bulk_total_size,
    sm.has_path_shares,
    sm.has_versioning,
    sm.has_content_hash,
    sm.has_confirm_upload,
    es.schema_name AS entity_schema,
    et.name AS entity_table
FROM metaschema_modules_public.storage_module AS sm
    LEFT JOIN metaschema_public.schema ps ON ps.id = sm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = sm.private_schema_id
    LEFT JOIN metaschema_modules_public.storage_module psm
    ON psm.scope = 'platform'
   AND psm.key = 'default'
   AND psm.database_id = (SELECT d.id FROM metaschema_public.database d WHERE d.platform)
    LEFT JOIN metaschema_public.table bt ON bt.id = sm.buckets_table_id
    LEFT JOIN metaschema_public.schema bs ON bs.id = bt.schema_id
    LEFT JOIN metaschema_public.table ft ON ft.id = sm.files_table_id
    LEFT JOIN metaschema_public.schema fs ON fs.id = ft.schema_id
    LEFT JOIN metaschema_public.table et ON et.id = sm.entity_table_id
    LEFT JOIN metaschema_public.schema es ON es.id = et.schema_id
WHERE ($1 IS NULL OR sm.database_id = $1)
  AND ($2 IS NULL OR sm.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.storage_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.transfer_log_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  transfer_log_table_name text,
  usage_summary_table_name text,
  rollup_function_name text,
  logs_per_database boolean,
  entity_field text,
  public_schema text,
  private_schema text
) AS $EOFCODE$
SELECT
    tlm.database_id,
    (tlm.database_id = app_scope.platform_database_id()) AS platform_owned,
    tlm.scope,
    tlm.transfer_log_table_name,
    tlm.usage_summary_table_name,
    tlm.rollup_function_name,
    EXISTS (SELECT 1 FROM metaschema_public.field AS f WHERE f.table_id = tlm.transfer_log_table_id AND f.name = 'database_id') AS logs_per_database,
    tlm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.transfer_log_module AS tlm
    LEFT JOIN metaschema_public.schema ps ON ps.id = tlm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = tlm.private_schema_id
WHERE tlm.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.transfer_log_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.user_auth_module_registrations(
  owner_database_id uuid
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  sweep_expired_sessions_function text,
  sweep_unverified_identifiers_function text,
  private_schema text
) AS $EOFCODE$
SELECT
    uam.database_id,
    (uam.database_id = app_scope.platform_database_id()) AS platform_owned,
    uam.sweep_expired_sessions_function,
    uam.sweep_unverified_identifiers_function,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.user_auth_module AS uam
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = uam.private_schema_id
WHERE uam.database_id = $1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.user_auth_module_registrations(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.webhook_module_registrations(
  owner_database_id uuid,
  surface_scope text DEFAULT NULL
) RETURNS TABLE (
  database_id uuid,
  platform_owned boolean,
  scope text,
  webhook_endpoints_table_name text,
  webhook_events_table_name text,
  entity_field text,
  public_schema text,
  private_schema text,
  signing_secrets_prefix text,
  signing_secrets_entity_field text,
  signing_secrets_schema text,
  namespaces_table_name text,
  namespaces_entity_field text,
  namespaces_schema text,
  function_invocation_module_id uuid
) AS $EOFCODE$
SELECT
    wm.database_id,
    (wm.database_id = app_scope.platform_database_id()) AS platform_owned,
    wm.scope,
    wm.webhook_endpoints_table_name,
    wm.webhook_events_table_name,
    wm.entity_field,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    ism.prefix AS signing_secrets_prefix,
    ism.entity_field AS signing_secrets_entity_field,
    iss.schema_name AS signing_secrets_schema,
    nsm.namespaces_table_name,
    nsm.entity_field AS namespaces_entity_field,
    nss.schema_name AS namespaces_schema,
    wm.function_invocation_module_id
FROM metaschema_modules_public.webhook_module AS wm
    LEFT JOIN metaschema_public.schema ps ON ps.id = wm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = wm.private_schema_id
    LEFT JOIN metaschema_modules_public.infra_secrets_module ism ON ism.id = wm.infra_secrets_module_id
    LEFT JOIN metaschema_public.schema iss ON iss.id = ism.schema_id
    LEFT JOIN metaschema_modules_public.namespace_module nsm ON nsm.id = wm.namespace_module_id
    LEFT JOIN metaschema_public.schema nss ON nss.id = nsm.schema_id
WHERE ($1 IS NULL OR wm.database_id = $1)
  AND ($2 IS NULL OR wm.scope = $2)
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.webhook_module_registrations(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.api_by_name(
  database_id uuid,
  api_name text
) RETURNS TABLE (
  api_id uuid,
  api_database_id uuid,
  dbname text,
  role_name text,
  anon_role text,
  is_public boolean,
  schemas text[]
) AS $EOFCODE$
BEGIN
    RETURN QUERY
    SELECT a.id, a.database_id, a.dbname::text, a.role_name::text, a.anon_role::text, a.is_published,
           COALESCE(array_agg(s.schema_name::text ORDER BY s.schema_name) FILTER (WHERE s.schema_name IS NOT NULL), '{}')
    FROM routing_public.apis AS a
    LEFT JOIN routing_public.api_schemas AS aps ON aps.api_id = a.id
    LEFT JOIN metaschema_public.schema AS s ON s.id = aps.schema_id
    WHERE a.database_id = api_by_name.database_id
      AND a.name = api_by_name.api_name
    GROUP BY a.id, a.database_id, a.dbname, a.role_name, a.anon_role, a.is_published;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.api_by_name(uuid, text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.api_hostnames(
  database_id uuid
) RETURNS SETOF text AS $EOFCODE$
BEGIN
    RETURN QUERY
    SELECT d.hostname::text
    FROM routing_public.domains AS d
    WHERE d.database_id = api_hostnames.database_id
      AND d.hostname IS NOT NULL
    ORDER BY 1;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.api_hostnames(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.service_principal(
  principal_name text
) RETURNS TABLE (
  user_id uuid,
  bypass_step_up boolean,
  owner_id uuid,
  owner_type int
) AS $EOFCODE$
DECLARE
    principals_schema text;
    principals_table text;
    users_schema text;
    users_table text;
BEGIN
    SELECT s.schema_name, pam.principals_table_name, us.schema_name, ut.name
    INTO principals_schema, principals_table, users_schema, users_table
    FROM metaschema_modules_public.principal_auth_module AS pam
    JOIN metaschema_public.schema AS s ON s.id = pam.schema_id
    LEFT JOIN metaschema_public.table AS ut ON ut.id = pam.users_table_id
    LEFT JOIN metaschema_public.schema AS us ON us.id = ut.schema_id
    WHERE pam.database_id = app_scope.platform_database_id();

    IF principals_schema IS NULL OR users_table IS NULL THEN
        RAISE EXCEPTION 'SERVICE_PRINCIPAL_MODULE_MISSING: the platform database has no principal_auth_module';
    END IF;

    -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: relation names come from the catalog registration, values are bound
    RETURN QUERY EXECUTE format(
        'SELECT p.user_id, p.bypass_step_up, owner.id, owner.type FROM %I.%I AS p '
        'LEFT JOIN %I.%I AS owner ON owner.id = p.owner_id WHERE p.name = $1',
        principals_schema, principals_table, users_schema, users_table
    ) USING service_principal.principal_name;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.service_principal(text) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.tenant_auth_entry(
  database_id uuid
) RETURNS TABLE (
  authenticate_schema text,
  authenticate_function text,
  authenticate_strict_function text,
  role_schema text,
  current_role_function text,
  current_role_id_function text,
  current_ip_address_function text,
  current_user_agent_function text
) AS $EOFCODE$
BEGIN
    RETURN QUERY
    SELECT auth_schema.schema_name::text, auth_fn.name::text, auth_strict_fn.name::text,
           role_schema.schema_name::text, role_fn.name::text, role_id_fn.name::text,
           ip_fn.name::text, ua_fn.name::text
    FROM routing_public.rls_settings AS rs
    JOIN metaschema_public.schema AS auth_schema ON auth_schema.id = rs.authenticate_schema_id
    JOIN metaschema_public.function AS auth_fn ON auth_fn.id = rs.authenticate_function_id
    LEFT JOIN metaschema_public.function AS auth_strict_fn ON auth_strict_fn.id = rs.authenticate_strict_function_id
    LEFT JOIN metaschema_public.schema AS role_schema ON role_schema.id = rs.role_schema_id
    LEFT JOIN metaschema_public.function AS role_fn ON role_fn.id = rs.current_role_function_id
    LEFT JOIN metaschema_public.function AS role_id_fn ON role_id_fn.id = rs.current_role_id_function_id
    LEFT JOIN metaschema_public.function AS ip_fn ON ip_fn.id = rs.current_ip_address_function_id
    LEFT JOIN metaschema_public.function AS ua_fn ON ua_fn.id = rs.current_user_agent_function_id
    WHERE rs.database_id = tenant_auth_entry.database_id
    LIMIT 1;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.tenant_auth_entry(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.database_export_catalog(
  database_id uuid
) RETURNS TABLE (
  database_name text,
  schema_id uuid,
  schema_label text,
  schema_name text
) AS $EOFCODE$
SELECT d.name::text, s.id, s.name::text, s.schema_name::text
FROM metaschema_public.database AS d
    LEFT JOIN metaschema_public.schema AS s ON s.database_id = d.id
WHERE d.id = $1
ORDER BY s.schema_name
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.database_export_catalog(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.storage_modules() RETURNS TABLE (
  id uuid,
  database_id uuid,
  scope text,
  buckets_table_id uuid,
  entity_field text,
  entity_table_id uuid,
  buckets_schema text,
  buckets_table text,
  files_schema text,
  files_table text,
  private_schema text,
  endpoint text,
  public_url_prefix text,
  provider text,
  region text,
  connection_overrides text[],
  allowed_origins text[],
  upload_url_expiry_seconds int,
  download_url_expiry_seconds int,
  default_max_file_size bigint,
  max_filename_length int,
  cache_ttl_seconds int,
  max_bulk_files int,
  max_bulk_total_size bigint,
  has_path_shares boolean,
  has_versioning boolean,
  has_content_hash boolean,
  has_confirm_upload boolean,
  entity_schema text,
  entity_table text
) AS $EOFCODE$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM metaschema_modules_public.storage_module AS psm
        JOIN metaschema_public.database AS d ON d.id = psm.database_id AND d.platform
        WHERE psm.scope = 'platform'
          AND psm.key = 'default'
          AND psm.endpoint IS NOT NULL
    ) THEN
        PERFORM errors.raise_error('STORAGE_PLATFORM_ENDPOINT_MISSING', '{}'::jsonb, 'internal');
    END IF;

    -- One projection of the storage configuration: the platform login's
    -- registrations reader, narrowed to the request's own database.
    RETURN QUERY
    SELECT
        r.id,
        r.database_id,
        r.scope,
        r.buckets_table_id,
        r.entity_field,
        r.entity_table_id,
        r.buckets_schema,
        r.buckets_table,
        r.files_schema,
        r.files_table,
        r.private_schema,
        r.endpoint,
        r.public_url_prefix,
        r.provider,
        r.region,
        r.connection_overrides,
        r.allowed_origins,
        r.upload_url_expiry_seconds,
        r.download_url_expiry_seconds,
        r.default_max_file_size,
        r.max_filename_length,
        r.cache_ttl_seconds,
        r.max_bulk_files,
        r.max_bulk_total_size,
        r.has_path_shares,
        r.has_versioning,
        r.has_content_hash,
        r.has_confirm_upload,
        r.entity_schema,
        r.entity_table
    FROM function_resolution.storage_module_registrations(jwt_private.require_database_id()) AS r
    WHERE r.buckets_table IS NOT NULL
      AND r.files_table IS NOT NULL;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.storage_modules() FROM PUBLIC RESTRICT;

GRANT EXECUTE ON FUNCTION function_resolution.storage_modules() TO authenticated, anonymous;

CREATE FUNCTION function_resolution.storage_file_ref_field(
  schema_name text,
  table_name text,
  field_name text
) RETURNS TABLE (
  id uuid,
  storage_module_id uuid,
  bucket_key text,
  bucket_tags text[],
  is_public boolean,
  enforce_fk boolean
) AS $EOFCODE$
    SELECT
        r.id,
        r.storage_module_id,
        r.bucket_key,
        r.bucket_tags,
        r.is_public,
        r.enforce_fk
    FROM function_resolution.file_ref_field_registrations(jwt_private.require_database_id()) AS r
    WHERE r.schema_name = storage_file_ref_field.schema_name
      AND r.table_name = storage_file_ref_field.table_name
      AND r.field_name = storage_file_ref_field.field_name
    LIMIT 1
$EOFCODE$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.storage_file_ref_field(text, text, text) FROM PUBLIC RESTRICT;

GRANT EXECUTE ON FUNCTION function_resolution.storage_file_ref_field(text, text, text) TO authenticated, anonymous;

CREATE FUNCTION function_resolution.cors_origins(
  database_id uuid,
  api_id uuid
) RETURNS TABLE (
  allowed_origins text[]
) AS $EOFCODE$
BEGIN
    RETURN QUERY
    SELECT cs.allowed_origins
    FROM routing_public.cors_settings AS cs
    WHERE cs.database_id = cors_origins.database_id
      AND (cs.api_id = cors_origins.api_id OR cs.api_id IS NULL)
    ORDER BY cs.api_id IS NULL
    LIMIT 1;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.cors_origins(uuid, uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.pubkey_entry(
  database_id uuid
) RETURNS TABLE (
  schema_name text,
  crypto_network text,
  sign_up_with_key text,
  sign_in_request_challenge text,
  sign_in_record_failure text,
  sign_in_with_challenge text
) AS $EOFCODE$
BEGIN
    RETURN QUERY
    SELECT s.schema_name::text, ps.crypto_network, sign_up_fn.name::text,
           sign_in_req_fn.name::text, sign_in_fail_fn.name::text, sign_in_fn.name::text
    FROM routing_public.pubkey_settings AS ps
    LEFT JOIN metaschema_public.schema AS s ON s.id = ps.schema_id
    LEFT JOIN metaschema_public.function AS sign_up_fn ON sign_up_fn.id = ps.sign_up_with_key_function_id
    LEFT JOIN metaschema_public.function AS sign_in_req_fn ON sign_in_req_fn.id = ps.sign_in_request_challenge_function_id
    LEFT JOIN metaschema_public.function AS sign_in_fail_fn ON sign_in_fail_fn.id = ps.sign_in_record_failure_function_id
    LEFT JOIN metaschema_public.function AS sign_in_fn ON sign_in_fn.id = ps.sign_in_with_challenge_function_id
    WHERE ps.database_id = pubkey_entry.database_id
    LIMIT 1;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.pubkey_entry(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.webauthn_entry(
  database_id uuid
) RETURNS TABLE (
  schema_name text,
  credentials_schema text,
  sessions_schema text,
  session_secrets_schema text,
  rp_id text,
  rp_name text,
  origin_allowlist text[],
  attestation_type text,
  require_user_verification boolean,
  resident_key text,
  challenge_expiry_seconds bigint
) AS $EOFCODE$
BEGIN
    RETURN QUERY
    SELECT s.schema_name::text, cred_s.schema_name::text, sess_s.schema_name::text,
           sec_s.schema_name::text, ws.rp_id, ws.rp_name, ws.origin_allowlist,
           ws.attestation_type, ws.require_user_verification, ws.resident_key,
           ws.challenge_expiry_seconds
    FROM routing_public.webauthn_settings AS ws
    LEFT JOIN metaschema_public.schema AS s ON s.id = ws.schema_id
    LEFT JOIN metaschema_public.schema AS cred_s ON cred_s.id = ws.credentials_schema_id
    LEFT JOIN metaschema_public.schema AS sess_s ON sess_s.id = ws.sessions_schema_id
    LEFT JOIN metaschema_public.schema AS sec_s ON sec_s.id = ws.session_secrets_schema_id
    WHERE ws.database_id = webauthn_entry.database_id
    LIMIT 1;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.webauthn_entry(uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.database_features(
  database_id uuid,
  api_id uuid
) RETURNS TABLE (
  enable_aggregates boolean,
  enable_postgis boolean,
  enable_search boolean,
  enable_direct_uploads boolean,
  enable_presigned_uploads boolean,
  enable_many_to_many boolean,
  enable_connection_filter boolean,
  enable_ltree boolean,
  enable_llm boolean,
  enable_realtime boolean,
  enable_bulk boolean,
  enable_i18n boolean
) AS $EOFCODE$
BEGIN
    RETURN QUERY
    SELECT COALESCE(aps.enable_aggregates, ds.enable_aggregates),
           COALESCE(aps.enable_postgis, ds.enable_postgis),
           COALESCE(aps.enable_search, ds.enable_search),
           COALESCE(aps.enable_direct_uploads, ds.enable_direct_uploads),
           COALESCE(aps.enable_presigned_uploads, ds.enable_presigned_uploads),
           COALESCE(aps.enable_many_to_many, ds.enable_many_to_many),
           COALESCE(aps.enable_connection_filter, ds.enable_connection_filter),
           COALESCE(aps.enable_ltree, ds.enable_ltree),
           COALESCE(aps.enable_llm, ds.enable_llm),
           COALESCE(aps.enable_realtime, ds.enable_realtime),
           COALESCE(aps.enable_bulk, ds.enable_bulk),
           COALESCE(aps.enable_i18n, ds.enable_i18n)
    FROM routing_public.database_settings AS ds
    LEFT JOIN routing_public.api_settings AS aps
      ON aps.database_id = ds.database_id AND aps.api_id = database_features.api_id
    WHERE ds.database_id = database_features.database_id
    LIMIT 1;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.database_features(uuid, uuid) FROM PUBLIC RESTRICT;

CREATE FUNCTION function_resolution.request_protection(
  database_id uuid,
  api_id uuid
) RETURNS TABLE (
  db_statement_timeout_ms bigint,
  db_idle_in_transaction_timeout_ms bigint,
  db_lock_timeout_ms bigint,
  db_max_concurrent_requests int,
  db_max_queue_wait_ms int,
  db_rate_limit_rpm int,
  db_rate_limit_burst int,
  db_max_query_depth int,
  db_max_query_cost int,
  db_max_page_size int,
  db_max_request_bytes int,
  db_enable_introspection boolean,
  api_statement_timeout_ms bigint,
  api_idle_in_transaction_timeout_ms bigint,
  api_lock_timeout_ms bigint,
  api_max_concurrent_requests int,
  api_max_queue_wait_ms int,
  api_rate_limit_rpm int,
  api_rate_limit_burst int,
  api_max_query_depth int,
  api_max_query_cost int,
  api_max_page_size int,
  api_max_request_bytes int,
  api_enable_introspection boolean
) AS $EOFCODE$
BEGIN
    RETURN QUERY
    SELECT ds.statement_timeout_ms,
           ds.idle_in_transaction_timeout_ms,
           ds.lock_timeout_ms,
           ds.max_concurrent_requests,
           ds.max_queue_wait_ms,
           ds.rate_limit_rpm,
           ds.rate_limit_burst,
           ds.max_query_depth,
           ds.max_query_cost,
           ds.max_page_size,
           ds.max_request_bytes,
           ds.enable_introspection,
           aps.statement_timeout_ms,
           aps.idle_in_transaction_timeout_ms,
           aps.lock_timeout_ms,
           aps.max_concurrent_requests,
           aps.max_queue_wait_ms,
           aps.rate_limit_rpm,
           aps.rate_limit_burst,
           aps.max_query_depth,
           aps.max_query_cost,
           aps.max_page_size,
           aps.max_request_bytes,
           aps.enable_introspection
    FROM routing_public.database_settings AS ds
    LEFT JOIN routing_public.api_settings AS aps
      ON aps.database_id = ds.database_id AND aps.api_id = request_protection.api_id
    WHERE ds.database_id = request_protection.database_id
    LIMIT 1;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.request_protection(uuid, uuid) FROM PUBLIC RESTRICT;