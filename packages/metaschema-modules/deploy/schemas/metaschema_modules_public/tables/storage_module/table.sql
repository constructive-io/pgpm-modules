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
    buckets_table_name text NOT NULL DEFAULT 'buckets',
    files_table_name text NOT NULL DEFAULT 'files',
    upload_requests_table_name text NOT NULL DEFAULT 'upload_requests',

    -- Entity table for RLS (users table, since users and orgs share it)
    entity_table_id uuid NULL,

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

COMMIT;
