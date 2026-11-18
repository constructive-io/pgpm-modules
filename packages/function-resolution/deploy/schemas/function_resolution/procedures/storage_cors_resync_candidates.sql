-- Deploy schemas/function_resolution/procedures/storage_cors_resync_candidates to pg

-- requires: schemas/function_resolution/schema

BEGIN;

-- The physical bucket ids a storage CORS reconciliation pass may inspect.
-- Exact storage-module membership and per-bucket origin inheritance are proved
-- separately through each plane's generated login-only `<buckets>_by_id`
-- reader. The catalog is the stable, typed source for owner attribution: a
-- shared platform storage plane may contain buckets owned by many databases.
CREATE FUNCTION function_resolution.storage_cors_resync_candidates(
    filter_database_id uuid DEFAULT NULL
) RETURNS TABLE (
    bucket_id uuid,
    owner_database_id uuid
) AS $$
BEGIN
    RETURN QUERY
    SELECT b.id, b.database_id
      FROM catalog_private.buckets b
     WHERE b.physical_name IS NOT NULL
       AND (storage_cors_resync_candidates.filter_database_id IS NULL
            OR b.database_id = storage_cors_resync_candidates.filter_database_id)
     ORDER BY b.id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.storage_cors_resync_candidates(uuid) FROM PUBLIC;

COMMIT;
