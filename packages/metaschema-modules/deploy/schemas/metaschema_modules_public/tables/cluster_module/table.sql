-- Deploy schemas/metaschema_modules_public/tables/cluster_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

-- The fleet catalog: Kubernetes clusters, the PostgreSQL servers a cluster owns,
-- the physical databases on those servers, and which logical (metaschema)
-- database is placed in which physical database.
--
-- Platform scope only. These rows describe fleet capacity, not tenant data, so
-- there is no per-tenant instance of them: the insert trigger refuses any scope
-- outside metaschema_private.constructive_scopes() and steps up to super
-- constructive. A tenant-visible answer to "where does my data live" is a view
-- over one placement row, never a second copy of these tables.
CREATE TABLE metaschema_modules_public.cluster_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Scope-key column name on the generated table(s), recorded by the insert
    -- trigger via metaschema_generators.scope_key_column(scope, key). Platform
    -- is a global tier, so this stays NULL — recorded as a queryable fact
    -- rather than re-derived by consumers.
    entity_field text,

    -- Schema references (if uuid_nil, resolved from schema name or default)
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Optional schema name overrides (used when schema IDs are not provided)
    public_schema_name text,
    private_schema_name text,

    -- Generated table IDs (populated by the generator)
    clusters_table_id uuid NOT NULL DEFAULT uuid_nil(),
    cluster_events_table_id uuid NOT NULL DEFAULT uuid_nil(),
    database_servers_table_id uuid NOT NULL DEFAULT uuid_nil(),
    physical_databases_table_id uuid NOT NULL DEFAULT uuid_nil(),
    database_placements_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table names (input to the generator)
    clusters_table_name text NOT NULL DEFAULT 'clusters',
    cluster_events_table_name text NOT NULL DEFAULT 'cluster_events',
    database_servers_table_name text NOT NULL DEFAULT 'database_servers',
    physical_databases_table_name text NOT NULL DEFAULT 'physical_databases',
    database_placements_table_name text NOT NULL DEFAULT 'database_placements',

    -- API routing (get-or-create: if set, schema is added to this API; if NULL,
    -- no API is added). The fleet catalog ships on its own `cluster` API so the
    -- admin surface is not widened with fleet-only concerns.
    api_name text,
    private_api_name text,

    -- Scope: determines the security level for this module instance.
    -- Resolved to a membership_type integer at trigger time via membership_types.
    -- Only the constructive scopes are accepted (see the insert trigger).
    scope text NOT NULL DEFAULT 'platform',

    -- Table name prefix. Auto-derived from scope by the trigger when empty and
    -- no dedicated API provides namespace isolation.
    prefix text NOT NULL DEFAULT '',

    -- Configurable security policies (NULL = use defaults based on scope).
    -- When provided, replaces the default policy set in apply_module_security.
    policies jsonb NULL,

    -- Per-table provisions overrides from blueprint config. Keys are table keys
    -- (clusters, cluster_events, database_servers, physical_databases,
    -- database_placements). When a key is present, the module trigger skips
    -- default security for that table.
    provisions jsonb NULL,

    -- Default capabilities auto-granted to new members.
    -- NULL uses the module's built-in defaults; explicit array overrides them.
    default_capabilities text[] DEFAULT NULL,

    -- Retention for the partitioned cluster_events tier
    partition_interval text NOT NULL DEFAULT '1 month',
    retention text NOT NULL DEFAULT '12 months',
    premake integer NOT NULL DEFAULT 2,

    -- Constraints
    CONSTRAINT cluster_module_db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT cluster_module_schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT cluster_module_private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT cluster_module_clusters_table_fkey FOREIGN KEY (clusters_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT cluster_module_events_table_fkey FOREIGN KEY (cluster_events_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT cluster_module_servers_table_fkey FOREIGN KEY (database_servers_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT cluster_module_physical_dbs_table_fkey FOREIGN KEY (physical_databases_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT cluster_module_placements_table_fkey FOREIGN KEY (database_placements_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

-- database_id needs no index of its own: cluster_module_unique_scope below
-- leads with it, so it already serves a lookup by database.
CREATE INDEX cluster_module_schema_id_idx ON metaschema_modules_public.cluster_module ( schema_id );
CREATE INDEX cluster_module_private_schema_id_idx ON metaschema_modules_public.cluster_module ( private_schema_id );
CREATE INDEX cluster_module_clusters_table_id_idx ON metaschema_modules_public.cluster_module ( clusters_table_id );
CREATE INDEX cluster_module_cluster_events_table_id_idx ON metaschema_modules_public.cluster_module ( cluster_events_table_id );
CREATE INDEX cluster_module_database_servers_table_id_idx ON metaschema_modules_public.cluster_module ( database_servers_table_id );
CREATE INDEX cluster_module_physical_databases_table_id_idx ON metaschema_modules_public.cluster_module ( physical_databases_table_id );
CREATE INDEX cluster_module_database_placements_table_id_idx ON metaschema_modules_public.cluster_module ( database_placements_table_id );

-- One cluster module per database per scope + prefix.
CREATE UNIQUE INDEX cluster_module_unique_scope ON metaschema_modules_public.cluster_module ( database_id, scope, prefix );

-- Tables this module generates, as opposed to tables it is handed: the
-- @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.cluster_module.clusters_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.cluster_module.cluster_events_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.cluster_module.database_servers_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.cluster_module.physical_databases_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.cluster_module.database_placements_table_id IS '@module_table';

COMMIT;
