-- Deploy schemas/function_resolution/procedures/resolve_default_bucket to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/frame_default_bucket
-- requires: schemas/function_resolution/procedures/storage_module_registrations
-- requires: schemas/function_resolution/procedures/memberships_module_registrations
-- requires: pgpm-jwt-claims:schemas/jwt_private/procedures/require_database_id
-- requires: pgpm-jwt-claims:schemas/jwt_public/procedures/current_user_id
-- requires: pgpm-jwt-claims:schemas/jwt_public/procedures/current_principal_id
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- resolve_default_bucket: the request lane's default bucket — what an upload
-- that names no bucketKey stores into — for the request's own database.
--
-- The frame is never the caller's to choose. The database is the request's
-- database claim, exactly as storage_modules() reads it, and the scope must be
-- one of that database's storage planes. The caller must then hold a membership
-- at that scope (its SPRT row, the plane every policy reads): of the entity for
-- an entity-scoped plane, of the app for a global one. Only then is the frame
-- handed to frame_default_bucket, which reads catalog_private.buckets past RLS.
-- Without these checks a caller could name another tenant's database or another
-- entity and read back its private default bucket id and physical name.
CREATE FUNCTION function_resolution.resolve_default_bucket(
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
    v_database_id uuid := jwt_private.require_database_id();
    v_actor_id uuid := COALESCE(jwt_public.current_principal_id(), jwt_public.current_user_id());
    v_entity_scoped boolean;
    v_membership_scope text;
    v_sprt_schema text;
    v_sprt_table text;
    v_is_member boolean;
BEGIN
    SELECT bool_or(r.entity_table_id IS NOT NULL)
    INTO v_entity_scoped
    FROM function_resolution.storage_module_registrations(v_database_id) AS r
    WHERE r.scope = resolve_default_bucket.scope;

    IF v_entity_scoped IS NULL THEN
        PERFORM errors.raise_error(
            'STORAGE_MODULE_NOT_FOUND',
            jsonb_build_object('scope', resolve_default_bucket.scope),
            'internal'
        );
    END IF;

    IF v_entity_scoped AND resolve_default_bucket.entity_id IS NULL THEN
        PERFORM errors.raise_error(
            'STORAGE_SCOPE_KEY_REQUIRED',
            jsonb_build_object('scope', resolve_default_bucket.scope),
            'internal'
        );
    END IF;

    IF NOT v_entity_scoped AND resolve_default_bucket.entity_id IS NOT NULL THEN
        PERFORM errors.raise_error(
            'STORAGE_SCOPE_KEY_UNEXPECTED',
            jsonb_build_object('scope', resolve_default_bucket.scope),
            'internal'
        );
    END IF;

    v_membership_scope := CASE WHEN v_entity_scoped THEN resolve_default_bucket.scope ELSE 'app' END;

    SELECT m.private_schema, m.sprt_table_name
    INTO v_sprt_schema, v_sprt_table
    FROM function_resolution.memberships_module_registrations(v_database_id) AS m
    WHERE m.scope = v_membership_scope;

    IF v_actor_id IS NOT NULL AND v_sprt_table IS NOT NULL THEN
        IF v_entity_scoped THEN
            -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the SPRT lives under the database's generated schema; identifiers are catalog data, values are bound
            EXECUTE format(
                'SELECT EXISTS (SELECT 1 FROM %I.%I m WHERE m.actor_id = $1 AND m.entity_id = $2)',
                v_sprt_schema, v_sprt_table
            ) INTO v_is_member USING v_actor_id, resolve_default_bucket.entity_id;
        ELSE
            -- pgsql-lint-disable-next-line no-dynamic-sql -- lookup-only: the SPRT lives under the database's generated schema; identifiers are catalog data, values are bound
            EXECUTE format(
                'SELECT EXISTS (SELECT 1 FROM %I.%I m WHERE m.actor_id = $1)',
                v_sprt_schema, v_sprt_table
            ) INTO v_is_member USING v_actor_id;
        END IF;
    END IF;

    IF v_is_member IS NOT TRUE THEN
        PERFORM errors.raise_error(
            'STORAGE_SCOPE_MEMBERSHIP_REQUIRED',
            jsonb_build_object(
                'scope', resolve_default_bucket.scope,
                'entity_id', resolve_default_bucket.entity_id
            ),
            'internal'
        );
    END IF;

    RETURN QUERY
    SELECT f.bucket_id, f.resolved_key, f.bucket_type, f.physical_name,
           f.owner_database_id, f.owner_scope, f.owner_key
    FROM function_resolution.frame_default_bucket(
        v_database_id,
        resolve_default_bucket.scope,
        resolve_default_bucket.entity_id,
        resolve_default_bucket.public_access,
        resolve_default_bucket.bucket_key
    ) AS f;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.resolve_default_bucket(text, uuid, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION function_resolution.resolve_default_bucket(text, uuid, boolean, text) TO authenticated;

COMMIT;
