-- Deploy schemas/function_resolution/procedures/resolve_api to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/frame_candidates
-- requires: schemas/function_resolution/procedures/api_catalog_row
-- requires: pgpm-app-scope:schemas/app_scope/procedures/routing_tables

BEGIN;

-- resolve_api: answer "which api surface does this selector mean for this
-- execution".
--
-- The selector vocabulary is module names — the same names the module presets
-- and provision_database_modules use — augmented to name a specific api when a
-- module has several, and a scope when a module is registered at several:
--
--   notifications_module              the module's api surface
--   capabilities_module.admin          this api from this module
--   limits_module@org                 the module's org-scope registration
--   capabilities_module.admin@org      both
--   admin                             an api by its owner-local name
--
-- Anything ending in _module (before its suffixes) is a module selector; a
-- plain word is an api name — the escape hatch, not the default.
--
-- The module form is the rename-safe one, and it needs no new column to be so:
-- module registration already attaches the module's schema to the api by row
-- (api_schemas.api_id -> apis.id, written by metaschema.add_schema_to_api), so
-- the association survives any rename of the api. The module config row's
-- api_name stays what it has always been — authoring input naming the surface
-- to attach to (and the tie-breaker when a bare module selector finds several
-- attached surfaces) — not the association itself.
--
-- Same determinism and reachability rules as resolve_bucket: most-specific
-- frame first, exactly one answer in the winning frame or a raise that names
-- the candidates, and a foreign-database api resolves only when is_visible.
--
-- The <api_name> path reads catalog_private.apis statically for every frame at
-- once, carrying each candidate's expected database_id so the shared plane
-- cannot answer one tenant's probe with another's row.
--
-- The <module> path's dynamic SQL is a different case, and is the only dynamic
-- SQL left in resolution: a module registration table is one relation per module type
-- (there is no catalog kind projecting them), so the selector genuinely names
-- the relation. It is lookup-only, the relation is proved to exist by an
-- ordinary catalog join first, and no value is ever interpolated — only the
-- verified relation name.
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
) AS $$
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
