-- Deploy schemas/metaschema_modules_public/tables/config_secrets_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.config_secrets_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Schema references (resolved by BEFORE INSERT trigger when uuid_nil)
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Generated table IDs (populated by the generator)
    table_id uuid NOT NULL DEFAULT uuid_nil(),
    config_definitions_table_id uuid NULL DEFAULT NULL,

    -- Table name (input — bare name without scope prefix).
    -- The trigger prepends the scope prefix automatically.
    table_name text NOT NULL DEFAULT 'secrets',

    -- API routing (get-or-create: if set, schema is added to this API)
    api_name text DEFAULT 'config',
    private_api_name text DEFAULT NULL,

    -- Scope: determines the security level for this module instance.
    -- Resolved to a membership_type integer at trigger time via membership_types table.
    -- 'app' = app-level (AuthzAppMembership, admin-only secrets + config)
    -- 'org' = org-scoped (AuthzEntityMembership, per-org secrets with manage_secrets permission)
    -- custom entity type names for entity-scoped secrets
    -- Note: user-scoped credentials are handled by user_credentials_module (separate module)
    scope text NOT NULL DEFAULT 'app',

    -- Table name prefix. Auto-derived from scope by the trigger when empty.
    -- Override to create multiple module instances at the same scope.
    prefix text NOT NULL DEFAULT '',

    -- Entity table for RLS (NULL for app-level, entity table for entity-scoped)
    entity_table_id uuid NULL,

    -- Configurable security policies (NULL = use defaults based on scope).
    -- When provided, replaces the default policy set in the security function.
    -- Accepts a JSON array of policy objects:
    --   {"$type": "AuthzEntityMembership", "privileges": ["select", "update"], "data": {...}}
    policies jsonb NULL,

    -- Per-table provisions overrides from blueprint config.
    -- Keys are table keys (secrets, config_definitions).
    -- When a key is present, the module trigger skips default security for that table;
    -- secure_table_provision applies the custom grants/policies instead.
    provisions jsonb NULL,

    -- Feature flags

    -- When true, also creates a plaintext config table ({prefix}_config) and
    -- a config definitions registry table ({prefix}_config_definitions).
    -- Only meaningful for app-level scope (scope = 'app').
    has_config boolean NOT NULL DEFAULT false,

    -- Constraints
    CONSTRAINT config_secrets_module_db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT config_secrets_module_schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT config_secrets_module_private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT config_secrets_module_table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT config_secrets_module_config_defs_table_fkey FOREIGN KEY (config_definitions_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT config_secrets_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

CREATE INDEX config_secrets_module_database_id_idx ON metaschema_modules_public.config_secrets_module ( database_id );
CREATE INDEX config_secrets_module_schema_id_idx ON metaschema_modules_public.config_secrets_module ( schema_id );
CREATE INDEX config_secrets_module_table_id_idx ON metaschema_modules_public.config_secrets_module ( table_id );

-- Unique constraint: one config_secrets module per database per scope per prefix.
CREATE UNIQUE INDEX config_secrets_module_unique_scope ON metaschema_modules_public.config_secrets_module ( database_id, scope, prefix );

COMMENT ON TABLE metaschema_modules_public.config_secrets_module IS
    'Entity-aware PGP-encrypted key-value config/secrets module. Supports app-level (admin-only)
     and org-scoped (per-org secrets with manage_secrets permission) via the scope column.
     User-scoped bcrypt credentials are handled by user_credentials_module.';

COMMIT;
