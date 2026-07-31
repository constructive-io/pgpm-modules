-- Deploy schemas/function_resolution/procedures/resolve to pg
-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/catalog_location
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/function_module/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/frames

BEGIN;

-- resolve: deterministic cross-scope function resolver, answered from the
-- typed functions catalog.
--
-- It expands the ordered frames from app_scope.frames into
-- (owner_scope, owner_key) candidates and runs ONE indexed read against the
-- typed functions catalog of each DISTINCT frame database (at most two in any
-- real chain: the execution database and the platform database).
-- app_scope.frames stays the single source of truth for ordering (and
-- cycle/depth safety).
--
-- Candidate expansion per frame:
--   * global frame (key_value NULL):  (scope, owner_key IS NULL)
--   * keyed frame:                    (scope, owner_key = key)   -- most specific
--                                then (scope, owner_key IS NULL) -- scope default
-- The catalog query is a LATERAL over the ordered candidate list with one
-- exact-equality branch per owner_key nullness, so each candidate is a single
-- probe of the catalog's partial unique indexes
-- ((owner_scope, owner_key, task_identifier) WHERE owner_key IS NOT NULL and
-- (owner_scope, task_identifier) WHERE owner_key IS NULL). Lowest candidate
-- ordinality across all frame databases wins.
--
-- Availability is fail-loud, never silent: a frame database that hosts
-- function modules but has no functions catalog cannot be answered, so the
-- typed FUNCTION_RESOLUTION_CATALOG_UNAVAILABLE (SQLSTATE FR001) is raised.
-- A frame database with neither function modules nor a catalog contributes
-- nothing and is skipped.
--
-- owner_database_id is the catalog row's owning database — the definition's
-- home database — so callers (routing) need no second frame walk to find it.
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
) AS $$
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
