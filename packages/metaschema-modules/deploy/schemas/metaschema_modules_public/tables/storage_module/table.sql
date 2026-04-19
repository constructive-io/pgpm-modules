-- Deploy schemas/metaschema_modules_public/tables/storage_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.storage_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Schema references
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Generated table IDs (populated by the generator)
    buckets_table_id uuid NOT NULL DEFAULT uuid_nil(),
    files_table_id uuid NOT NULL DEFAULT uuid_nil(),
    upload_requests_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table names (input to the generator)
    buckets_table_name text NOT NULL DEFAULT 'app_buckets',
    files_table_name text NOT NULL DEFAULT 'app_files',
    upload_requests_table_name text NOT NULL DEFAULT 'app_upload_requests',

    -- Multi-tenant storage identity
    membership_type int DEFAULT NULL,              -- NULL = global gate (AuthzMembership via app_sprt), non-NULL = entity-scoped (AuthzEntityMembership)

    -- Entity table for RLS (NULL for app-level storage, entity table for entity-scoped storage)
    entity_table_id uuid NULL,

    -- S3 connection config (NULL = use global env/plugin defaults)
    endpoint text NULL,                          -- S3-compatible API endpoint URL (MinIO, R2, DO Spaces, GCS, etc.)
    public_url_prefix text NULL,                 -- Public URL prefix for generating download URLs (e.g., CDN domain)
    provider text NULL,                          -- Storage provider type: 'minio', 's3', 'gcs', etc.

    -- CORS configuration (NULL = use plugin defaults)
    allowed_origins text[] NULL,                 -- Default CORS origins for all buckets in this database (e.g., ARRAY['https://app.example.com']). ['*'] = open/CDN mode.

    -- Per-database configurable settings (NULL = use plugin defaults)
    upload_url_expiry_seconds integer NULL,      -- Presigned PUT URL expiry (default: 900 = 15 min)
    download_url_expiry_seconds integer NULL,    -- Presigned GET URL expiry (default: 3600 = 1 hour)
    default_max_file_size bigint NULL,           -- Global max file size in bytes (default: 200MB). Bucket-level overrides this.
    max_filename_length integer NULL,            -- Max filename length in chars (default: 1024)
    cache_ttl_seconds integer NULL,              -- LRU cache TTL for this config (default: 300 dev / 3600 prod)

    -- Constraints
    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT buckets_table_fkey FOREIGN KEY (buckets_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT files_table_fkey FOREIGN KEY (files_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT upload_requests_table_fkey FOREIGN KEY (upload_requests_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

CREATE INDEX storage_module_database_id_idx ON metaschema_modules_public.storage_module ( database_id );

-- Unique constraint on (database_id, membership_type) using COALESCE to handle NULLs.
-- NULL membership_type = app-level (only one per database), non-NULL = entity-scoped (one per membership_type per database).
CREATE UNIQUE INDEX storage_module_unique_scope ON metaschema_modules_public.storage_module ( database_id, COALESCE(membership_type, -1) );

COMMIT;
