-- Deploy schemas/function_resolution/procedures/api_catalog_row to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/frame_candidates

BEGIN;

-- api_catalog_row: load one api surface the execution is allowed to reach, by id.
--
-- Same reachability rule the bucket path uses: the api must be owned by a frame
-- in the execution's own chain, and an api owned by another database
-- additionally needs is_visible. This is what keeps an explicit api binding —
-- or a module attachment resolved in an outer frame — from handing a function
-- another tenant's surface.
--
-- One indexed read: the frame candidates join catalog_private.apis, nearest
-- frame first. The shared plane holds every database's rows, so each candidate
-- carries the row's expected database_id (its own key at database scope, the
-- frame's lookup database otherwise) — without it a binding could be proved
-- against another tenant's surface.
--
-- Returns no row when the api is not reachable; the caller owns the wording,
-- because it knows the selector that named it.
--
-- plpgsql, not sql: this module is portable and deploys into databases that host
-- no catalog module, so catalog_private must be resolved on first call rather
-- than at CREATE FUNCTION time.
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
) AS $$
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
