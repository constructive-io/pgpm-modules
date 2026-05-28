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
    secret_definitions_table_id uuid NOT NULL DEFAULT uuid_nil(),
    requirements_table_id uuid NOT NULL DEFAULT uuid_nil(),
    config_definitions_table_id uuid NOT NULL DEFAULT uuid_nil(),
    config_requirements_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table names (input to the generator — bare names without scope prefix).
    -- The trigger prepends the scope prefix automatically.
    definitions_table_name text NOT NULL DEFAULT 'function_definitions',
    invocations_table_name text NOT NULL DEFAULT 'function_invocations',
    execution_logs_table_name text NOT NULL DEFAULT 'function_execution_logs',
    secret_definitions_table_name text NOT NULL DEFAULT 'secret_definitions',
    requirements_table_name text NOT NULL DEFAULT 'function_secret_requirements',
    config_requirements_table_name text NOT NULL DEFAULT 'function_config_requirements',

    -- API routing (get-or-create: if set, schema is added to this API; if NULL, no API is added)
    api_name text,
    private_api_name text,

    -- Multi-tenant function identity
    membership_type int DEFAULT NULL,              -- NULL = database-root (AuthzMembership via app_sprt), non-NULL = entity-scoped (AuthzEntityMembership)

    -- Scope prefix for table naming.  Auto-derived from membership_type when
    -- NULL:  NULL/1 → 'app',  2 → 'org'.  Can be overridden explicitly.
    -- The trigger prepends this to all bare table names
    -- (e.g. prefix='app' + 'function_definitions' → 'app_function_definitions').
    prefix text NULL,

    -- Module key discriminator: allows multiple function modules per scope.
    -- 'default' is omitted from table names, any other value becomes
    -- an infix: {prefix}_{key}_function_definitions.
    -- Max 16 chars, lowercase snake_case.
    key text NOT NULL DEFAULT 'default',

    -- Entity table for RLS (NULL for app-level functions, entity table for entity-scoped functions)
    entity_table_id uuid NULL,

    -- Configurable security policies (NULL = use defaults based on membership_type).
    -- When provided, replaces the default policy set in apply_function_security.
    -- Accepts a JSON array of policy objects:
    --   {"$type": "AuthzEntityMembership", "privileges": ["select", "update"], "data": {...}}
    policies jsonb NULL,

    -- Per-table provisions overrides from blueprint config.
    -- Keys are table keys (definitions, invocations, execution_logs, secret_definitions, requirements).
    -- When a key is present, the module trigger skips default security for that table;
    -- secure_table_provision applies the custom grants/policies instead.
    provisions jsonb NULL,

    -- Constraints
    CONSTRAINT function_module_db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT function_module_schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT function_module_private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT function_module_definitions_table_fkey FOREIGN KEY (definitions_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT function_module_invocations_table_fkey FOREIGN KEY (invocations_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT function_module_execution_logs_table_fkey FOREIGN KEY (execution_logs_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT function_module_secret_defs_table_fkey FOREIGN KEY (secret_definitions_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT function_module_requirements_table_fkey FOREIGN KEY (requirements_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT function_module_config_defs_table_fkey FOREIGN KEY (config_definitions_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT function_module_config_reqs_table_fkey FOREIGN KEY (config_requirements_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT function_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

CREATE INDEX function_module_database_id_idx ON metaschema_modules_public.function_module ( database_id );

-- Unique constraint on (database_id, membership_type, key) using COALESCE to handle NULLs.
-- NULL membership_type = app-level, non-NULL = entity-scoped. key discriminates
-- multiple function modules for the same scope (e.g. 'webhooks' + 'automations').
CREATE UNIQUE INDEX function_module_unique_scope ON metaschema_modules_public.function_module ( database_id, COALESCE(membership_type, -1), key );

COMMIT;
