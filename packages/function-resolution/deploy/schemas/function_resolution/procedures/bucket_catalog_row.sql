-- Deploy schemas/function_resolution/procedures/bucket_catalog_row to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/frame_candidates

BEGIN;

-- bucket_catalog_row: load one bucket the execution is allowed to reach, by id.
--
-- This is where a capability binding's target is proved to belong to the
-- caller's tenant. The generated binding guard cannot do it: compute's
-- published platform modules must stay self-contained, so nothing generated
-- into compute may reference a storage table. Resolution can — the binding is
-- honoured only when the bucket is reachable from the execution's own frame
-- chain, and a bucket owned by another database additionally needs is_visible.
-- A binding pointing anywhere else returns nothing rather than handing a
-- function a foreign tenant's storage.
--
-- One indexed read: the frame candidates join catalog_private.buckets, nearest
-- frame first. The shared plane holds every database's rows, so each candidate
-- carries the row's expected database_id (its own key at database scope, the
-- frame's lookup database otherwise) — without it a binding could be "proved"
-- against a row belonging to another tenant, which is the exact hazard this
-- function exists to stop.
--
-- Returns no row when the bucket is not reachable, leaving the fail-loud
-- wording to the caller, which knows the capability key that named it.
--
-- plpgsql, not sql: this module is portable and deploys into databases that host
-- no catalog module, so catalog_private must be resolved on first call rather
-- than at CREATE FUNCTION time.
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
) AS $$
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
