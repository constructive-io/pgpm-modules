-- Deploy schemas/metaschema_modules_public/tables/graph_module/table to pg

-- requires: schemas/metaschema_modules_public/schema
-- requires: schemas/metaschema_modules_public/tables/merkle_store_module/table

BEGIN;

CREATE TABLE metaschema_modules_public.graph_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Schema references (if uuid_nil, resolved from schema name or default)
    public_schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Optional schema name overrides (used when schema IDs are not provided)
    public_schema_name text,
    private_schema_name text,

    -- Table/function prefix (e.g., 'pipeline' -> pipeline_function_graphs, ...)
    -- Stored normalized (no trailing underscore); underscore added at generation time
    prefix text NOT NULL DEFAULT '',

    -- Reference to the Merkle store this graph module depends on
    merkle_store_module_id uuid NOT NULL,

    -- Generated table IDs (populated by BEFORE INSERT trigger)
    graphs_table_id uuid NOT NULL DEFAULT uuid_nil(),
    executions_table_id uuid NOT NULL DEFAULT uuid_nil(),
    outputs_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- API routing (get-or-create: if set, schema is added to this API; if NULL, no API is added)
    api_name text,
    private_api_name text,

    -- Scope field name (column used for multi-tenant isolation)
    scope_field text NOT NULL DEFAULT 'scope_id',

    -- Multi-tenant scoping (entity-aware module pattern)
    membership_type int DEFAULT NULL,              -- NULL = database-root, non-NULL = entity-scoped
    entity_table_id uuid NULL,                     -- Entity table for entity-scoped RLS

    -- Configurable security policies (NULL = use defaults).
    -- Accepts a JSON array of policy objects:
    --   {"$type": "AuthzEntityMembership", "privileges": ["select", "update"], "data": {...}}
    policies jsonb NULL,

    -- Per-table provisions overrides from blueprint config.
    -- Keys are table keys (graphs, executions, outputs).
    -- When a key is present, the module trigger skips default security for that table;
    -- secure_table_provision applies the custom grants/policies instead.
    provisions jsonb NULL,

    -- Timestamps
    created_at timestamptz NOT NULL DEFAULT now(),

    -- Constraints
    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT public_schema_fkey FOREIGN KEY (public_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT merkle_store_fkey FOREIGN KEY (merkle_store_module_id) REFERENCES metaschema_modules_public.merkle_store_module (id) ON DELETE CASCADE,
    CONSTRAINT graphs_table_fkey FOREIGN KEY (graphs_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT executions_table_fkey FOREIGN KEY (executions_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT outputs_table_fkey FOREIGN KEY (outputs_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT graph_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,

    -- Only one graph module per database + merkle store combination
    CONSTRAINT graph_module_database_merkle_unique UNIQUE (database_id, merkle_store_module_id)
);

CREATE INDEX graph_module_database_id_idx ON metaschema_modules_public.graph_module ( database_id );

COMMIT;
