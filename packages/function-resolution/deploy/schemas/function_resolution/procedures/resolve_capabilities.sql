-- Deploy schemas/function_resolution/procedures/resolve_capabilities to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/definitions_location
-- requires: schemas/function_resolution/procedures/frame_candidates
-- requires: schemas/function_resolution/procedures/resolve_bucket
-- requires: schemas/function_resolution/procedures/bucket_catalog_row
-- requires: schemas/function_resolution/procedures/bound_bucket_id
-- requires: schemas/function_resolution/procedures/resolve_api
-- requires: schemas/function_resolution/procedures/resolve_payload_refs

BEGIN;

-- resolve_capabilities: turn one resolved function definition plus one raw
-- payload into the bundle an invocation runs with — resolve-before-dispatch.
--
-- This is the single implementation of capability resolution, and it must stay
-- single: the worker calls it before invoking a function, and a graph node that
-- resolves capabilities for downstream nodes is a wrapper over this same
-- function. Two implementations would be two answers to "which bucket is
-- this".
--
-- A definition declares tenant-agnostically (required_buckets keys,
-- required_modules selectors); a tenant fulfils either by labelling its own
-- rows (discovery) or by writing a capability binding (the deterministic
-- override).
--
-- Where the definition lives and where it runs are separate: a platform-scope
-- definition is invoked inside a tenant's (or an org's, or a department's)
-- frame chain and RLS world, which is why the execution triple
-- (database_id, scope, entity_id) is taken apart from the definition's
-- (definition_scope, definition_database_id). Every requirement resolves
-- against the *execution's* frames, so one image serves every scope.
-- Every capability therefore has exactly one answer here, or the invocation
-- fails loudly before any code runs — a function never receives a half-built
-- context, and never selects a resource itself.
--
-- Buckets resolve in three tiers, and only the third one reaches this
-- declaration path:
--   1. record-associated resources are stamped into the payload when the
--      trigger is created (the $ref is already resolved: passed through),
--   2. a file field's bucket is a metaschema fact, queried where it is used,
--   3. function-owned resources (scratch, exports, variants) are declared in
--      required_buckets and resolved here.
--
-- The returned bundle carries coordinates and handles only. Secret and config
-- requirements come back as the names the definition declared — never values:
-- those resolve per invocation through the realm's getter inside the runtime,
-- so a credential never enters a payload, a bundle, or a queue row.
CREATE FUNCTION function_resolution.resolve_capabilities(
    database_id uuid,
    scope text,
    entity_id uuid,
    function_definition_id uuid,
    definition_scope text,
    definition_database_id uuid DEFAULT NULL,
    payload jsonb DEFAULT '{}'::jsonb,
    channel text DEFAULT NULL
) RETURNS jsonb AS $$
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
