-- Deploy schemas/metaschema_modules_public/tables/function_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.function_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Schema references (if uuid_nil, resolved from schema name or default)
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Optional schema name overrides (used when schema IDs are not provided)
    public_schema_name text,
    private_schema_name text,

    -- Generated table IDs (populated by the generator)
    definitions_table_id uuid NOT NULL DEFAULT uuid_nil(),
    invocations_table_id uuid NOT NULL DEFAULT uuid_nil(),
    execution_logs_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table names (input to the generator)
    definitions_table_name text NOT NULL DEFAULT 'function_definitions',
    invocations_table_name text NOT NULL DEFAULT 'function_invocations',
    execution_logs_table_name text NOT NULL DEFAULT 'function_execution_logs',

    -- API routing (get-or-create: if set, schema is added to this API; if NULL, no API is added)
    api_name text,
    private_api_name text,

    -- Multi-tenant function identity
    membership_type int DEFAULT NULL,              -- NULL = database-root (AuthzMembership via app_sprt), non-NULL = entity-scoped (AuthzEntityMembership)

    -- Entity table for RLS (NULL for app-level functions, entity table for entity-scoped functions)
    entity_table_id uuid NULL,

    -- Configurable security policies (NULL = use defaults based on membership_type).
    -- When provided, replaces the default policy set in apply_function_security.
    -- Accepts a JSON array of policy objects:
    --   {"$type": "AuthzEntityMembership", "privileges": ["select", "update"], "data": {...}}
    policies jsonb NULL,

    -- Constraints
    CONSTRAINT function_module_db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT function_module_schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT function_module_private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT function_module_definitions_table_fkey FOREIGN KEY (definitions_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT function_module_invocations_table_fkey FOREIGN KEY (invocations_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT function_module_execution_logs_table_fkey FOREIGN KEY (execution_logs_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT function_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

CREATE INDEX function_module_database_id_idx ON metaschema_modules_public.function_module ( database_id );

-- Unique constraint on (database_id, membership_type) using COALESCE to handle NULLs.
-- NULL membership_type = app-level, non-NULL = entity-scoped.
-- Only one function module per scope.
CREATE UNIQUE INDEX function_module_unique_scope ON metaschema_modules_public.function_module ( database_id, COALESCE(membership_type, -1) );

COMMIT;
