-- Deploy schemas/function_resolution/procedures/resolve_bucket to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/frame_candidates

BEGIN;

-- resolve_bucket: answer "which bucket serves this selector for this
-- execution", from the published buckets catalog.
--
-- The selector is {tags, type}: tag containment plus an optional access-type
-- filter. That is the whole vocabulary, on purpose — a function definition is
-- tenant-agnostic (one image serves many databases, so it cannot name a bucket
-- id) and a bucket's key is owner-local identity a tenant names whatever it
-- likes, so meaning lives in labels the tenant applies. Conventions like
-- uploads / variants / exports are documentation, not DDL: nothing in the
-- schema constrains a tenant to one bucket per tag.
--
-- Determinism is enforced here rather than by a unique index: candidates are
-- probed most-specific frame first, and the winning frame must answer with
-- exactly one bucket. Zero matches and several matches both raise, and the
-- ambiguous error names the candidates so the fix (retag, narrow by type, or
-- write an explicit capability binding) is obvious.
--
-- Cross-scope reach follows the catalog's own visibility rule: a bucket owned
-- by another database resolves only when is_visible (propagated from the
-- source row's is_public), so an outer frame's private bucket is unreachable.
--
-- One static set-based query answers every frame at once. The shared plane holds
-- every logical database's rows, so each candidate carries the row's expected
-- database_id — the candidate's own key at database scope, the frame's lookup
-- database otherwise — exactly as resolve() does for functions. Without it one
-- tenant's probe could be answered by another tenant's row.
--
-- A frame database without a buckets catalog simply contributes no candidates:
-- storage is an optional module, so its absence is not a provisioning error the
-- way a missing functions catalog is.
CREATE FUNCTION function_resolution.resolve_bucket(
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
DECLARE
    v_matches jsonb;
    v_match jsonb;
BEGIN
    IF resolve_bucket.tags IS NULL OR cardinality(resolve_bucket.tags) = 0 THEN
        RAISE EXCEPTION 'CAPABILITY_BUCKET_SELECTOR_EMPTY: a bucket selector needs at least one tag (database_id=%, scope="%")',
            resolve_bucket.database_id, resolve_bucket.scope
            USING ERRCODE = 'FR010';
    END IF;

    -- Every frame in one indexed read, keeping only the matches of the most
    -- specific frame that answered: a nearer frame outranks an outer one, and
    -- ties within that frame are the ambiguity raised below.
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
            resolve_bucket.database_id,
            resolve_bucket.scope,
            resolve_bucket.entity_id
        ) cand
        JOIN catalog_private.buckets b
          ON b.owner_scope = cand.owner_scope
         AND b.owner_key IS NOT DISTINCT FROM cand.owner_key
         AND b.database_id = CASE
               WHEN cand.owner_scope = 'database' THEN cand.owner_key
               ELSE cand.lookup_database_id
             END
        WHERE b.tags @> resolve_bucket.tags
          AND (resolve_bucket.type_filter IS NULL OR b.type = resolve_bucket.type_filter)
          AND (b.database_id = resolve_bucket.database_id OR b.is_visible)
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
        RAISE EXCEPTION 'CAPABILITY_BUCKET_NOT_FOUND: no bucket tagged % % resolves in the scope chain starting at scope "%" (database_id=%)',
            resolve_bucket.tags,
            COALESCE('of type ' || resolve_bucket.type_filter, '(any type)'),
            resolve_bucket.scope,
            resolve_bucket.database_id
            USING ERRCODE = 'FR011';
    END IF;

    IF jsonb_array_length(v_matches) > 1 THEN
        RAISE EXCEPTION 'CAPABILITY_BUCKET_AMBIGUOUS: % buckets tagged % % resolve equally (candidates: %); retag, narrow by type, or bind the capability explicitly',
            jsonb_array_length(v_matches),
            resolve_bucket.tags,
            COALESCE('of type ' || resolve_bucket.type_filter, '(any type)'),
            (SELECT string_agg(format('%s (%s)', m->>'key', m->>'id'), ', ' ORDER BY m->>'key')
               FROM jsonb_array_elements(v_matches) m)
            USING ERRCODE = 'FR012';
    END IF;

    v_match := v_matches->0;

    resolve_bucket.bucket_id := (v_match->>'id')::uuid;
    resolve_bucket.bucket_key := v_match->>'key';
    resolve_bucket.bucket_type := v_match->>'type';
    resolve_bucket.physical_name := v_match->>'physical_name';
    resolve_bucket.owner_database_id := (v_match->>'database_id')::uuid;
    resolve_bucket.owner_scope := v_match->>'owner_scope';
    resolve_bucket.owner_key := (v_match->>'owner_key')::uuid;

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
