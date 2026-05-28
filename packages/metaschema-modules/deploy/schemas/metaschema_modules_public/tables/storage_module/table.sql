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

    -- Table names (input to the generator)
    buckets_table_name text NOT NULL DEFAULT 'app_buckets',
    files_table_name text NOT NULL DEFAULT 'app_files',

    -- Multi-tenant storage identity
    membership_type int DEFAULT NULL,              -- NULL = global gate (AuthzMembership via app_sprt), non-NULL = entity-scoped (AuthzEntityMembership)

    -- Module key discriminator: allows multiple storage modules per entity type.
    -- 'default' is omitted from table names (backward compat), any other value becomes
    -- an infix: {prefix}_{key}_{buckets|files}.
    -- Max 16 chars, lowercase snake_case, cannot be 'buckets'/'files'/'bucket'/'file'.
    key text NOT NULL DEFAULT 'default',

    -- Configurable security policies (NULL = use defaults based on membership_type).
    -- When provided, replaces the default policy set in apply_storage_security.
    -- Accepts a JSON array of policy objects:
    --   {"$type": "AuthzEntityMembership", "privileges": ["select", "update"], "data": {...}}
    policies jsonb NULL,

    -- Per-table provisions overrides from blueprint config.
    -- Keys are table keys (files, buckets).
    -- When a key is present, the module trigger skips default security for that table;
    -- secure_table_provision applies the custom grants/policies instead.
    provisions jsonb NULL,

    -- Entity table for RLS (NULL for app-level storage, entity table for entity-scoped storage)
    entity_table_id uuid NULL,

    -- S3 connection config (NULL = use global env/plugin defaults)
    endpoint text NULL,                          -- S3-compatible API endpoint URL (MinIO, R2, DO Spaces, GCS, etc.)
    public_url_prefix text NULL,                 -- Public URL prefix for generating download URLs (e.g., CDN domain)
    provider text NULL,                          -- Storage provider type: 'minio', 's3', 'gcs', etc.

    -- CORS configuration (NULL = use plugin defaults)
    allowed_origins text[] NULL,                 -- Default CORS origins for all buckets in this database (e.g., ARRAY['https://app.example.com']). ['*'] = open/CDN mode.

    -- Storage permissions: when true, SELECT on files requires read_files permission
    -- (opt-in restrictive mode for sensitive entity types like data rooms with confidential docs).
    -- When false (default), any entity member can read all files (baseline = membership).
    restrict_reads boolean NOT NULL DEFAULT false,

    -- Virtual filesystem + path shares: when true, generates the ltree path column
    -- on files, the file_path_shares table, and path share RLS policies.
    -- Enables folder hierarchy, per-folder/file sharing, and version chains.
    has_path_shares boolean NOT NULL DEFAULT false,

    -- Generated table ID for file_path_shares (populated by the generator when has_path_shares=true)
    path_shares_table_id uuid NULL DEFAULT NULL,

    -- Per-database configurable settings (NULL = use plugin defaults)
    upload_url_expiry_seconds integer NULL,      -- Presigned PUT URL expiry (default: 900 = 15 min)
    download_url_expiry_seconds integer NULL,    -- Presigned GET URL expiry (default: 3600 = 1 hour)
    default_max_file_size bigint NULL,           -- Global max file size in bytes (default: 200MB). Bucket-level overrides this.
    max_filename_length integer NULL,            -- Max filename length in chars (default: 1024)
    cache_ttl_seconds integer NULL,              -- LRU cache TTL for this config (default: 300 dev / 3600 prod)

    -- Bulk upload limits (NULL = use plugin defaults)
    max_bulk_files integer NULL,                 -- Max files per requestBulkUploadUrls batch (default: 100)
    max_bulk_total_size bigint NULL,             -- Max total size per batch in bytes (default: 1GB = 1073741824)

    -- Feature flags: toggleable storage capabilities (all default false for minimal footprint)
    has_versioning boolean NOT NULL DEFAULT false,   -- Version chains: previous_version_id, is_latest, version_history()
    has_content_hash boolean NOT NULL DEFAULT false,  -- Content hash column for dedup + integrity verification
    has_custom_keys boolean NOT NULL DEFAULT false,   -- allow_custom_keys on buckets (implies has_versioning + has_content_hash)
    has_audit_log boolean NOT NULL DEFAULT false,     -- File events audit table: upload, delete, move, rename, download, share events
    has_confirm_upload boolean NOT NULL DEFAULT false,  -- Deferred HeadObject confirmation: enqueues storage:confirm_upload job on INSERT, creates status transition functions
    confirm_upload_delay interval NOT NULL DEFAULT '30 seconds',  -- Delay before first confirmation attempt (only used when has_confirm_upload = true)

    -- Generated table ID for file_events (populated by the generator when has_audit_log=true)
    file_events_table_id uuid NULL DEFAULT NULL,

    -- Constraints
    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT buckets_table_fkey FOREIGN KEY (buckets_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT files_table_fkey FOREIGN KEY (files_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT path_shares_table_fkey FOREIGN KEY (path_shares_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT file_events_table_fkey FOREIGN KEY (file_events_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

CREATE INDEX storage_module_database_id_idx ON metaschema_modules_public.storage_module ( database_id );

-- Unique constraint on (database_id, membership_type, key) using COALESCE to handle NULLs.
-- NULL membership_type = app-level, non-NULL = entity-scoped. key discriminates
-- multiple storage modules for the same entity type (e.g. 'default' + 'fn').
CREATE UNIQUE INDEX storage_module_unique_scope ON metaschema_modules_public.storage_module ( database_id, COALESCE(membership_type, -1), key );

COMMIT;
