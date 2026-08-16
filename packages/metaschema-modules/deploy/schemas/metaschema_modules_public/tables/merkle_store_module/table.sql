-- Deploy schemas/metaschema_modules_public/tables/merkle_store_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.merkle_store_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,


    -- Scope-key column name on the generated table(s), recorded by the insert
    -- trigger via metaschema_generators.scope_key_column(scope, key): database ->
    -- 'database_id', entity -> the module's key ('entity_id' here), global -> NULL.
    entity_field text,
    -- Schema references (if uuid_nil, resolved from schema name or default)
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Optional schema name overrides (used when schema IDs are not provided)
    public_schema_name text,
    private_schema_name text,

    -- Generated table IDs (populated by BEFORE INSERT trigger)
    object_table_id uuid NOT NULL DEFAULT uuid_nil(),
    store_table_id uuid NOT NULL DEFAULT uuid_nil(),
    commit_table_id uuid NOT NULL DEFAULT uuid_nil(),
    ref_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table/function prefix (e.g., 'graph' -> graph_object, graph_store, ...)
    -- Stored normalized (no trailing underscore); underscore added at generation time
    prefix text NOT NULL DEFAULT '',

    -- API routing (get-or-create: if set, schema is added to this API; if NULL, no API is added)
    api_name text,
    private_api_name text,

    -- Scope: 'app' for app-level, 'platform' for database-scoped with
    -- RLS through metaschema_public.database ownership.
    scope text NOT NULL,

    -- The table an entity scope's entities live in, resolved by the insert
    -- trigger from the memberships module at `scope`. NULL at every non-entity
    -- scope, which carry an opaque store partition key instead of an owner.
    entity_table_id uuid NULL,

    -- Function name prefix override: NULL (default) inherits from `prefix`;
    -- '' (empty string) generates unprefixed function names (e.g., get_all instead of function_graph_get_all);
    -- any other value is used as-is. Tables always keep their prefix regardless of this setting.
    function_prefix text DEFAULT NULL,

    -- Capability key for SELECT gating: when set, all 4 merkle tables require this
    -- capability for SELECT at platform/app scope (e.g., 'manage_graphs').
    -- NULL means the caller intentionally wants open membership SELECT.
    capability_key text DEFAULT NULL,

    -- Timestamps
    created_at timestamptz NOT NULL DEFAULT now(),

    -- Constraints
    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT object_table_fkey FOREIGN KEY (object_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT store_table_fkey FOREIGN KEY (store_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT commit_table_fkey FOREIGN KEY (commit_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT ref_table_fkey FOREIGN KEY (ref_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT merkle_store_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,

    -- Only one merkle store module per database + prefix combination
    CONSTRAINT merkle_store_module_database_prefix_unique UNIQUE (database_id, prefix)
);

CREATE INDEX merkle_store_module_private_schema_id_idx ON metaschema_modules_public.merkle_store_module ( private_schema_id );
CREATE INDEX merkle_store_module_commit_table_id_idx ON metaschema_modules_public.merkle_store_module ( commit_table_id );
CREATE INDEX merkle_store_module_object_table_id_idx ON metaschema_modules_public.merkle_store_module ( object_table_id );
CREATE INDEX merkle_store_module_ref_table_id_idx ON metaschema_modules_public.merkle_store_module ( ref_table_id );
CREATE INDEX merkle_store_module_store_table_id_idx ON metaschema_modules_public.merkle_store_module ( store_table_id );
CREATE INDEX merkle_store_module_schema_id_idx ON metaschema_modules_public.merkle_store_module ( schema_id );
CREATE INDEX merkle_store_module_entity_table_id_idx ON metaschema_modules_public.merkle_store_module ( entity_table_id );

-- Tables this module generates, as opposed to tables it is handed (an
-- entity or users table it points at): the @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.merkle_store_module.commit_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.merkle_store_module.object_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.merkle_store_module.ref_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.merkle_store_module.store_table_id IS '@module_table';

COMMIT;
