-- Deploy schemas/function_resolution/procedures/resolve to pg
-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/function_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/catalog_module/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/frames

BEGIN;

-- resolve: deterministic cross-scope function resolver, answered from the
-- published functions catalog in ONE static indexed read.
--
-- It expands the ordered frames from app_scope.frames into
-- (owner_scope, owner_key) candidates and probes catalog_private.functions once
-- for all of them. app_scope.frames stays the single source of truth for
-- ordering (and cycle/depth safety).
--
-- Candidate expansion per frame:
--   * global frame (key_value NULL):  (scope, owner_key IS NULL)
--   * keyed frame:                    (scope, owner_key = key)   -- most specific
--                                then (scope, owner_key IS NULL) -- scope default
-- The query is a LATERAL over the ordered candidate list with one
-- exact-equality branch per owner_key nullness, so each candidate is a single
-- probe of the catalog's partial unique indexes
-- ((database_id, owner_scope, owner_key, task_identifier) WHERE owner_key IS NOT
-- NULL and (database_id, owner_scope, task_identifier) WHERE owner_key IS NULL).
-- Lowest candidate ordinality wins, which is frame precedence.
--
-- One physical relation holds every database's rows, so each candidate carries
-- the row-identity predicate that plane needs: a database-scope row stamps its
-- own database key (metaschema_generators.scope_key_column: only 'database' has
-- one), every other scope stamps the writing session's database, so the expected
-- database_id is the candidate's owner_key at database scope and the frame's
-- lookup database otherwise. Without it the shared plane would answer one
-- tenant's probe with another tenant's row.
--
-- Availability is fail-loud, never silent: a frame database that hosts function
-- modules but has no catalog module cannot be answered, so the typed
-- FUNCTION_RESOLUTION_CATALOG_UNAVAILABLE (SQLSTATE FR001) is raised. A frame
-- database with neither contributes nothing and is skipped.
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
