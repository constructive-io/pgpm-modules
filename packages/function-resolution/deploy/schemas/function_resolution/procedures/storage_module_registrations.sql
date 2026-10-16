-- Deploy schemas/function_resolution/procedures/storage_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/storage_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/database/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- storage_module_registrations: the storage_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: owner_database_id answers a database's own
-- instances, surface_scope a shared surface across databases, and NULL leaves that
-- side unfiltered. Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.storage_module_registrations(owner_database_id uuid, surface_scope text DEFAULT NULL)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    buckets_table_name text,
    files_table_name text,
    allowed_origins text[],
    public_schema text,
    private_schema text,
    endpoint text,
    provider text,
    region text,
    public_url_prefix text,
    connection_overrides text[],
    id uuid,
    entity_field text,
    buckets_table_id uuid,
    entity_table_id uuid,
    buckets_schema text,
    buckets_table text,
    files_schema text,
    files_table text,
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
SELECT
    sm.database_id,
    (sm.database_id = app_scope.platform_database_id()) AS platform_owned,
    sm.scope,
    sm.buckets_table_name,
    sm.files_table_name,
    sm.allowed_origins,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    psm.endpoint AS endpoint,
    psm.provider AS provider,
    psm.region AS region,
    coalesce(sm.public_url_prefix, psm.public_url_prefix) AS public_url_prefix,
    array_remove(ARRAY[
      CASE WHEN sm.endpoint IS DISTINCT FROM psm.endpoint AND sm.endpoint IS NOT NULL THEN 'endpoint' END,
    CASE WHEN sm.provider IS DISTINCT FROM psm.provider AND sm.provider IS NOT NULL THEN 'provider' END,
    CASE WHEN sm.region IS DISTINCT FROM psm.region AND sm.region IS NOT NULL THEN 'region' END
    ], NULL) AS connection_overrides,
    sm.id,
    sm.entity_field,
    sm.buckets_table_id,
    sm.entity_table_id,
    bs.schema_name AS buckets_schema,
    bt.name AS buckets_table,
    fs.schema_name AS files_schema,
    ft.name AS files_table,
    sm.upload_url_expiry_seconds,
    sm.download_url_expiry_seconds,
    sm.default_max_file_size,
    sm.max_filename_length,
    sm.cache_ttl_seconds,
    sm.max_bulk_files,
    sm.max_bulk_total_size,
    sm.has_path_shares,
    sm.has_versioning,
    sm.has_content_hash,
    sm.has_confirm_upload,
    es.schema_name AS entity_schema,
    et.name AS entity_table
FROM metaschema_modules_public.storage_module AS sm
    LEFT JOIN metaschema_public.schema ps ON ps.id = sm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = sm.private_schema_id
    LEFT JOIN metaschema_modules_public.storage_module psm
    ON psm.scope = 'platform'
   AND psm.key = 'default'
   AND psm.database_id = (SELECT d.id FROM metaschema_public.database d WHERE d.platform)
    LEFT JOIN metaschema_public.table bt ON bt.id = sm.buckets_table_id
    LEFT JOIN metaschema_public.schema bs ON bs.id = bt.schema_id
    LEFT JOIN metaschema_public.table ft ON ft.id = sm.files_table_id
    LEFT JOIN metaschema_public.schema fs ON fs.id = ft.schema_id
    LEFT JOIN metaschema_public.table et ON et.id = sm.entity_table_id
    LEFT JOIN metaschema_public.schema es ON es.id = et.schema_id
WHERE ($1 IS NULL OR sm.database_id = $1)
  AND ($2 IS NULL OR sm.scope = $2)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.storage_module_registrations(uuid, text) FROM PUBLIC;

COMMIT;
