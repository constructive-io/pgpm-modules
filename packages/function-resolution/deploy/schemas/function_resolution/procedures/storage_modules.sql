-- Deploy schemas/function_resolution/procedures/storage_modules to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/storage_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/database/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-jwt-claims:schemas/jwt_private/procedures/require_database_id
-- requires: errors:schemas/errors/procedures/raise_error
-- requires: schemas/function_resolution/procedures/storage_module_registrations

BEGIN;

-- storage_modules: the request database's storage configuration, read on the
-- request's own anonymous/authenticated lane.
--
-- The GraphQL storage plugins (upload, download, bulk limits) need every
-- storage_module of the database they serve, but RLS shows those rows only to
-- members of the owning org, and anonymous holds no grant on the metaschema at
-- all. This is the one narrow hop past that: the database is the caller's own
-- jwt.claims.database_id (missing raises), never an argument, so a caller can
-- only ever read its own database's modules.
--
-- Endpoint, provider and region come from the platform database's `platform`
-- plane, the only object store the deployment's credentials belong to;
-- `connection_overrides` names any a row sets differently so signing can
-- refuse it. A NULL public_url_prefix inherits the platform's. A missing
-- platform plane or endpoint raises STORAGE_PLATFORM_ENDPOINT_MISSING rather
-- than handing back NULL connection columns. Nothing here is a credential, and
-- no other database's row is returned.
CREATE FUNCTION function_resolution.storage_modules()
RETURNS TABLE (
    id uuid,
    database_id uuid,
    scope text,
    buckets_table_id uuid,
    entity_field text,
    entity_table_id uuid,
    buckets_schema text,
    buckets_table text,
    files_schema text,
    files_table text,
    private_schema text,
    endpoint text,
    public_url_prefix text,
    provider text,
    region text,
    connection_overrides text[],
    allowed_origins text[],
    upload_url_expiry_seconds integer,
    download_url_expiry_seconds integer,
    default_max_file_size bigint,
    max_filename_length integer,
    cache_ttl_seconds integer,
    max_bulk_files integer,
    max_bulk_total_size bigint,
    has_path_shares boolean,
    has_versioning boolean,
    has_content_hash boolean,
    has_confirm_upload boolean,
    entity_schema text,
    entity_table text
) AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM metaschema_modules_public.storage_module AS psm
        JOIN metaschema_public.database AS d ON d.id = psm.database_id AND d.platform
        WHERE psm.scope = 'platform'
          AND psm.key = 'default'
          AND psm.endpoint IS NOT NULL
    ) THEN
        PERFORM errors.raise_error('STORAGE_PLATFORM_ENDPOINT_MISSING', '{}'::jsonb, 'internal');
    END IF;

    -- One projection of the storage configuration: the platform login's
    -- registrations reader, narrowed to the request's own database.
    RETURN QUERY
    SELECT
        r.id,
        r.database_id,
        r.scope,
        r.buckets_table_id,
        r.entity_field,
        r.entity_table_id,
        r.buckets_schema,
        r.buckets_table,
        r.files_schema,
        r.files_table,
        r.private_schema,
        r.endpoint,
        r.public_url_prefix,
        r.provider,
        r.region,
        r.connection_overrides,
        r.allowed_origins,
        r.upload_url_expiry_seconds,
        r.download_url_expiry_seconds,
        r.default_max_file_size,
        r.max_filename_length,
        r.cache_ttl_seconds,
        r.max_bulk_files,
        r.max_bulk_total_size,
        r.has_path_shares,
        r.has_versioning,
        r.has_content_hash,
        r.has_confirm_upload,
        r.entity_schema,
        r.entity_table
    FROM function_resolution.storage_module_registrations(jwt_private.require_database_id()) AS r
    WHERE r.buckets_table IS NOT NULL
      AND r.files_table IS NOT NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.storage_modules() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION function_resolution.storage_modules() TO authenticated, anonymous;

COMMIT;
