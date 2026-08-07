-- Deploy schemas/function_resolution/procedures/resolve_invocation to pg
-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/resolve
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/catalog_module/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/frames

BEGIN;

-- resolve_invocation: the single entry point the generated invocations BEFORE
-- INSERT trigger calls. It records the definition identity exactly once,
-- consistently for every path (REST/GraphQL/cron/graph/worker):
--
--   * pair already supplied (worker/cron/API set function_definition_id):
--     keep it, defaulting definition_scope to the invocation's own module scope,
--     and validate the pair actually resolves — one indexed read against the
--     typed functions catalog of the declared scope's frame database. The
--     scope's lookup database + key come from app_scope.frames, so validation
--     keys exactly like resolution (e.g. an `org` pair keys by the owning org,
--     not the database). Validation is static SQL against
--     catalog_private.functions, keyed by the same database_id the catalog-sync
--     triggers stamp (the scope key at database scope, the writing database
--     otherwise), so one tenant's pair can never be validated against another's
--     row. A frame database without a functions catalog raises
--     FUNCTION_RESOLUTION_CATALOG_UNAVAILABLE (SQLSTATE FR001).
--   * otherwise: resolve deterministically across scopes. Definition-less
--     invocations stay allowed (require_definition => false), leaving both
--     columns NULL when nothing resolves.
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
) AS $$
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
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMIT;
