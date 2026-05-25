-- Deploy schemas/metaschema_modules_public/tables/merkle_store_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.merkle_store_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Schema reference (if uuid_nil, resolved from public_schema_name or default)
    schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Optional schema name override (used when schema_id is not provided)
    public_schema_name text,

    -- Generated table IDs (populated by BEFORE INSERT trigger)
    object_table_id uuid NOT NULL DEFAULT uuid_nil(),
    store_table_id uuid NOT NULL DEFAULT uuid_nil(),
    commit_table_id uuid NOT NULL DEFAULT uuid_nil(),
    ref_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table/function prefix (e.g., 'graph' -> graph_object, graph_store, ...)
    -- Stored normalized (no trailing underscore); underscore added at generation time
    prefix text NOT NULL DEFAULT '',

    -- API name (if set, schema is added to this API; if NULL, no API is added)
    api_name text,

    -- Scope field name (column used for multi-tenant isolation)
    scope_field text NOT NULL DEFAULT 'scope_id',

    -- Timestamps
    created_at timestamptz NOT NULL DEFAULT now(),

    -- Constraints
    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT object_table_fkey FOREIGN KEY (object_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT store_table_fkey FOREIGN KEY (store_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT commit_table_fkey FOREIGN KEY (commit_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT ref_table_fkey FOREIGN KEY (ref_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,

    -- Only one merkle store module per database + prefix combination
    CONSTRAINT merkle_store_module_database_prefix_unique UNIQUE (database_id, prefix)
);

CREATE INDEX merkle_store_module_database_id_idx ON metaschema_modules_public.merkle_store_module ( database_id );

COMMIT;
