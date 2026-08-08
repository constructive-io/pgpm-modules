-- Deploy schemas/function_resolution/procedures/bucket_matches to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/frame_candidates

BEGIN;

-- bucket_matches: every bucket the nearest answering frame offers for a
-- {tags, type} selector — the lookup half of bucket resolution, with no opinion
-- about how many rows are acceptable.
--
-- Split out so that "which buckets match" has exactly one implementation while
-- each caller states its own arity rule: resolve_bucket demands one for a
-- capability declaration, resolve_default_bucket demands one for a database's
-- default, and both raise on zero or several. A second copy of this query would
-- be a second answer to "which bucket is this".
--
-- One static set-based query answers every frame at once. The shared plane holds
-- every logical database's rows, so each candidate carries the row's expected
-- database_id — the candidate's own key at database scope, the frame's lookup
-- database otherwise. Without it one tenant's probe could be answered by another
-- tenant's row.
--
-- Candidates are probed most-specific frame first and only the nearest frame
-- that answered contributes rows: a nearer frame outranks an outer one, and ties
-- within that frame are the ambiguity a caller raises on.
--
-- Cross-scope reach follows the catalog's own visibility rule: a bucket owned by
-- another database matches only when is_visible (propagated from the source
-- row's is_public), so an outer frame's private bucket is unreachable.
--
-- A frame database without a buckets catalog simply contributes no candidates:
-- storage is an optional module, so its absence is not a provisioning error the
-- way a missing functions catalog is.
--
-- plpgsql, not sql: this module is portable and deploys into databases that host
-- no catalog module, so catalog_private must be resolved on first call rather
-- than at CREATE FUNCTION time.
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
) AS $$
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
