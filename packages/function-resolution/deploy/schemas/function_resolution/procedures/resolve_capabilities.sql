-- Deploy schemas/function_resolution/procedures/resolve_capabilities to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/definitions_location
-- requires: schemas/function_resolution/procedures/frame_candidates
-- requires: schemas/function_resolution/procedures/resolve_bucket
-- requires: schemas/function_resolution/procedures/bucket_catalog_row
-- requires: schemas/function_resolution/procedures/bound_bucket_id
-- requires: schemas/function_resolution/procedures/resolve_api
-- requires: schemas/function_resolution/procedures/resolve_payload_refs
-- requires: pgpm-app-scope:schemas/app_scope/procedures/frames

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
-- (function_definition_id, definition_scope). Every requirement resolves
-- against the *execution's* frames, so one image serves every scope.
-- Every capability therefore has exactly one answer here, or the invocation
-- fails loudly before any code runs — a function never receives a half-built
-- context, and never selects a resource itself.
--
-- Where the definition's row physically lives is decided by app_scope.frames,
-- never by the caller. The execution's frames at definition_scope are walked
-- in order and each frame's lookup database is asked for its function module
-- (definitions_location); the row is read from the first surface that holds
-- it, keyed by that frame's key_value in the module's recorded entity_field.
-- That is what lets a hosted tenant — one with no function module of its own —
-- run a `database`-scope definition that lives on the platform database's
-- shared surface: the table is the platform's, the row is the tenant's
-- (database_id = the tenant), and a row keyed to any other tenant is not found
-- on that table. Global frames (app/platform) carry no key and no key column.
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
    payload jsonb DEFAULT '{}'::jsonb,
    channel text DEFAULT NULL
) RETURNS jsonb AS $$
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
