-- Deploy schemas/function_resolution/procedures/resolve_staging_bucket to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/bucket_matches
-- requires: schemas/function_resolution/procedures/staging_bucket_tag

BEGIN;

-- resolve_staging_bucket: answer "which bucket does this database stage an
-- upload through", server-side, by the same rule resolve_default_bucket uses
-- for the destination.
--
-- Staging is not a second mechanism: the reserved staging tag is matched in the
-- caller's own frame chain, filtered to type = 'temp', and exactly one match is
-- the only acceptable answer. Zero raises (a module whose storage bootstrap
-- never labelled a staging bucket cannot silently stage into its permanent
-- bucket), several raise naming the candidates (picking one would stage a
-- tenant's uploads through whichever bucket sorted first).
--
-- The staging bucket's destination is its own destination_bucket_id, enforced on
-- the module's buckets table, so promotion reads the destination from the row
-- rather than being handed one by a client.
CREATE FUNCTION function_resolution.resolve_staging_bucket(
    database_id uuid,
    scope text,
    entity_id uuid
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
    v_tag := function_resolution.staging_bucket_tag();

    SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m.bucket_id), '[]'::jsonb)
    INTO v_matches
    FROM function_resolution.bucket_matches(
        resolve_staging_bucket.database_id,
        resolve_staging_bucket.scope,
        resolve_staging_bucket.entity_id,
        ARRAY[v_tag],
        'temp'
    ) m;

    IF jsonb_array_length(v_matches) = 0 THEN
        PERFORM errors.raise_error(
            'STORAGE_STAGING_BUCKET_NOT_FOUND',
            jsonb_build_object(
                'database_id', resolve_staging_bucket.database_id,
                'scope', resolve_staging_bucket.scope,
                'entity_id', resolve_staging_bucket.entity_id,
                'tag', v_tag
            ),
            'internal'
        );
    END IF;

    IF jsonb_array_length(v_matches) > 1 THEN
        PERFORM errors.raise_error(
            'STORAGE_STAGING_BUCKET_AMBIGUOUS',
            jsonb_build_object(
                'database_id', resolve_staging_bucket.database_id,
                'scope', resolve_staging_bucket.scope,
                'entity_id', resolve_staging_bucket.entity_id,
                'tag', v_tag,
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

    resolve_staging_bucket.bucket_id := (v_match->>'bucket_id')::uuid;
    resolve_staging_bucket.resolved_key := v_match->>'bucket_key';
    resolve_staging_bucket.bucket_type := v_match->>'bucket_type';
    resolve_staging_bucket.physical_name := v_match->>'physical_name';
    resolve_staging_bucket.owner_database_id := (v_match->>'owner_database_id')::uuid;
    resolve_staging_bucket.owner_scope := v_match->>'owner_scope';
    resolve_staging_bucket.owner_key := (v_match->>'owner_key')::uuid;

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMIT;
