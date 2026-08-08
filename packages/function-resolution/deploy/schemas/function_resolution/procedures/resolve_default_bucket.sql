-- Deploy schemas/function_resolution/procedures/resolve_default_bucket to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/bucket_matches
-- requires: schemas/function_resolution/procedures/default_bucket_tag

BEGIN;

-- resolve_default_bucket: answer "which bucket does this database store into
-- when the caller did not name one", server-side.
--
-- Bucket choice belongs to the database, never to a client: a client-chosen
-- string means a different bucket per tenant, and an environment-level bucket
-- means storage that does not belong to any tenant at all. So there is no
-- global fallback here and no default that resolves outside the execution's own
-- frame chain — a database either labelled a default bucket or it has none, and
-- the second case raises.
--
-- Two routes, one rule:
--   * bucket_key given -- the per-field override. A logical key is a label, the
--     same vocabulary a function's required_buckets declares, so the override
--     resolves through the identical match: nothing here is key-specific.
--   * bucket_key omitted -- the reserved default tag for the requested access
--     (see default_bucket_tag): 'default' or 'default-public'.
--
-- Either way the match must be exactly one bucket. Zero raises, several raise
-- naming the candidates, and nothing is guessed in between: an ambiguous default
-- is a tenant's tagging mistake, and picking one would silently write a tenant's
-- files into whichever bucket sorted first.
CREATE FUNCTION function_resolution.resolve_default_bucket(
    database_id uuid,
    scope text,
    entity_id uuid,
    public_access boolean,
    bucket_key text DEFAULT NULL
) RETURNS TABLE (
    bucket_id uuid,
    resolved_key text,
    bucket_type text,
    physical_name text,
    owner_database_id uuid,
    owner_scope text,
    owner_key uuid
) AS $$
DECLARE
    v_tag text;
    v_matches jsonb;
    v_match jsonb;
BEGIN
    -- A blank override is a caller bug, not a request for the default: falling
    -- through to tag resolution would turn a broken field binding into a
    -- silently different bucket.
    IF resolve_default_bucket.bucket_key IS NOT NULL
       AND btrim(resolve_default_bucket.bucket_key) = '' THEN
        PERFORM errors.raise_error(
            'STORAGE_BUCKET_KEY_BLANK',
            jsonb_build_object(
                'database_id', resolve_default_bucket.database_id,
                'scope', resolve_default_bucket.scope
            ),
            'internal'
        );
    END IF;

    v_tag := COALESCE(
        resolve_default_bucket.bucket_key,
        function_resolution.default_bucket_tag(resolve_default_bucket.public_access)
    );

    SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m.bucket_id), '[]'::jsonb)
    INTO v_matches
    FROM function_resolution.bucket_matches(
        resolve_default_bucket.database_id,
        resolve_default_bucket.scope,
        resolve_default_bucket.entity_id,
        ARRAY[v_tag]
    ) m;

    IF jsonb_array_length(v_matches) = 0 THEN
        PERFORM errors.raise_error(
            'STORAGE_DEFAULT_BUCKET_NOT_FOUND',
            jsonb_build_object(
                'database_id', resolve_default_bucket.database_id,
                'scope', resolve_default_bucket.scope,
                'entity_id', resolve_default_bucket.entity_id,
                'tag', v_tag,
                'explicit_key', resolve_default_bucket.bucket_key IS NOT NULL
            ),
            'internal'
        );
    END IF;

    IF jsonb_array_length(v_matches) > 1 THEN
        PERFORM errors.raise_error(
            'STORAGE_DEFAULT_BUCKET_AMBIGUOUS',
            jsonb_build_object(
                'database_id', resolve_default_bucket.database_id,
                'scope', resolve_default_bucket.scope,
                'entity_id', resolve_default_bucket.entity_id,
                'tag', v_tag,
                'explicit_key', resolve_default_bucket.bucket_key IS NOT NULL,
                'candidates', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'bucket_id', c->>'bucket_id',
                        'key', c->>'bucket_key',
                        'type', c->>'bucket_type'
                    ) ORDER BY c->>'bucket_key')
                    FROM jsonb_array_elements(v_matches) c
                )
            ),
            'internal'
        );
    END IF;

    v_match := v_matches->0;

    resolve_default_bucket.bucket_id := (v_match->>'bucket_id')::uuid;
    resolve_default_bucket.resolved_key := v_match->>'bucket_key';
    resolve_default_bucket.bucket_type := v_match->>'bucket_type';
    resolve_default_bucket.physical_name := v_match->>'physical_name';
    resolve_default_bucket.owner_database_id := (v_match->>'owner_database_id')::uuid;
    resolve_default_bucket.owner_scope := v_match->>'owner_scope';
    resolve_default_bucket.owner_key := (v_match->>'owner_key')::uuid;

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
