-- Deploy schemas/function_resolution/procedures/resolve_bucket to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/frame_candidates
-- requires: schemas/function_resolution/procedures/bucket_matches

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
-- Determinism is enforced here rather than by a unique index: bucket_matches
-- probes candidates most-specific frame first, and the winning frame must answer
-- with exactly one bucket. Zero matches and several matches both raise, and the
-- ambiguous error names the candidates so the fix (retag, narrow by type, or
-- write an explicit capability binding) is obvious.
--
-- The match itself — frames, same-tenant proof, cross-scope visibility, and the
-- absent-catalog case — lives in bucket_matches, so a capability declaration and
-- a database's default bucket are answered by one query under one arity rule.
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
    SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m.bucket_id), '[]'::jsonb)
    INTO v_matches
    FROM function_resolution.bucket_matches(
        resolve_bucket.database_id,
        resolve_bucket.scope,
        resolve_bucket.entity_id,
        resolve_bucket.tags,
        resolve_bucket.type_filter
    ) m;

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
            (SELECT string_agg(format('%s (%s)', m->>'bucket_key', m->>'bucket_id'), ', ' ORDER BY m->>'bucket_key')
               FROM jsonb_array_elements(v_matches) m)
            USING ERRCODE = 'FR012';
    END IF;

    v_match := v_matches->0;

    resolve_bucket.bucket_id := (v_match->>'bucket_id')::uuid;
    resolve_bucket.bucket_key := v_match->>'bucket_key';
    resolve_bucket.bucket_type := v_match->>'bucket_type';
    resolve_bucket.physical_name := v_match->>'physical_name';
    resolve_bucket.owner_database_id := (v_match->>'owner_database_id')::uuid;
    resolve_bucket.owner_scope := v_match->>'owner_scope';
    resolve_bucket.owner_key := (v_match->>'owner_key')::uuid;

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
