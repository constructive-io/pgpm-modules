-- Deploy schemas/function_resolution/procedures/bound_bucket_id to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/frame_candidates

BEGIN;

-- bound_bucket_id: the bucket a capability binding fulfils one declared key
-- with, or NULL when the tenant left the key to discovery.
--
-- A binding is the deterministic override: it exists precisely for the cases
-- discovery cannot answer — two buckets share a tag, or a tenant wants an
-- audited, explicit grant instead of a labelling convention. It is therefore
-- consulted before tags, and the row nearest the execution wins: candidates are
-- ordered most-specific first, matching the frame's scope key so one entity's
-- grant never leaks to another.
--
-- Lifecycle orders the tie within one frame: an execution-scoped binding is
-- more specific than a root-execution one, which is more specific than a
-- deployment-wide one. ('deployment' | 'execution' | 'root_execution' are the
-- lifecycle values function_module's check constraint allows — when a capability
-- applies, not a scope.)
--
-- The shared plane holds every database's rows, so each candidate carries the
-- row's expected database_id (its own key at database scope, the frame's lookup
-- database otherwise): without it, a binding written by another tenant at the
-- same (scope, key) coordinates would answer this execution.
--
-- No is_visible predicate, unlike the buckets and apis catalogs: a binding is
-- not a cross-scope claim. It is reachable only through a frame of the
-- execution that holds it, which is exactly the authority the scoped source
-- table carried — so the projection is read with the frame identity alone, and
-- nothing about visibility widens or narrows it.
--
-- The bucket returned here is NOT yet proven reachable — bucket_catalog_row
-- does that. Keeping the two apart is what lets the caller name the capability
-- key in the error.
--
-- plpgsql, not sql: this module is portable and deploys into databases that host
-- no catalog module, so catalog_private must be resolved on first call rather
-- than at CREATE FUNCTION time.
CREATE FUNCTION function_resolution.bound_bucket_id(
    database_id uuid,
    scope text,
    entity_id uuid,
    function_definition_id uuid,
    key text
) RETURNS uuid AS $$
DECLARE
    v_bucket_id uuid;
BEGIN
    SELECT b.bucket_id
    INTO v_bucket_id
    FROM function_resolution.frame_candidates(
        bound_bucket_id.database_id,
        bound_bucket_id.scope,
        bound_bucket_id.entity_id
    ) cand
    JOIN catalog_private.bindings b
      ON b.owner_scope = cand.owner_scope
     AND b.owner_key IS NOT DISTINCT FROM cand.owner_key
     AND b.database_id = CASE
           WHEN cand.owner_scope = 'database' THEN cand.owner_key
           ELSE cand.lookup_database_id
         END
    WHERE b.function_id = bound_bucket_id.function_definition_id
      AND b.key = bound_bucket_id.key
      AND b.bucket_id IS NOT NULL
    ORDER BY cand.ord,
             CASE b.lifecycle
                 WHEN 'execution' THEN 0
                 WHEN 'root_execution' THEN 1
                 ELSE 2
             END
    LIMIT 1;

    RETURN v_bucket_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
