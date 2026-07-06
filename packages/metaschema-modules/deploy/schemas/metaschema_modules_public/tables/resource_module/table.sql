-- Deploy schemas/metaschema_modules_public/tables/resource_module/table to pg

-- requires: schemas/metaschema_modules_public/schema
-- requires: schemas/metaschema_modules_public/tables/namespace_module/table

BEGIN;

CREATE TABLE metaschema_modules_public.resource_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Schema references (if uuid_nil, resolved from schema name or default)
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Optional schema name overrides (used when schema IDs are not provided)
    public_schema_name text,
    private_schema_name text,

    -- Generated table IDs (populated by the generator)
    resources_table_id uuid NOT NULL DEFAULT uuid_nil(),
    resource_events_table_id uuid NOT NULL DEFAULT uuid_nil(),
    resource_status_checks_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table names (input to the generator — bare names without scope prefix).
    -- The trigger prepends the scope prefix automatically.
    resources_table_name text NOT NULL DEFAULT 'resources',
    resource_events_table_name text NOT NULL DEFAULT 'resource_events',
    resource_status_checks_table_name text NOT NULL DEFAULT 'resource_status_checks',

    -- API routing (get-or-create: if set, schema is added to this API; if NULL, no API is added)
    api_name text,
    private_api_name text,

    -- Scope: determines the security level for this module instance.
    scope text NOT NULL DEFAULT 'app',

    -- Table name prefix. Auto-derived from scope by the trigger when empty.
    prefix text NOT NULL DEFAULT '',

    -- Entity table for RLS (NULL for app-level resources, entity table for entity-scoped)
    entity_table_id uuid NULL,

    -- FK to namespace_module: which namespaces table resources are scoped to
    namespace_module_id uuid NULL,

    -- Configurable security policies (NULL = use defaults based on scope).
    policies jsonb NULL,

    -- Per-table provisions overrides from blueprint config.
    -- Keys are table keys (resources, resource_events).
    provisions jsonb NULL,

    -- Default permissions: permission names auto-granted to new members.
    default_permissions text[] DEFAULT NULL,

    -- Constraints
    CONSTRAINT resource_module_db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT resource_module_schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT resource_module_private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT resource_module_resources_table_fkey FOREIGN KEY (resources_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT resource_module_events_table_fkey FOREIGN KEY (resource_events_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT resource_module_status_checks_table_fkey FOREIGN KEY (resource_status_checks_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT resource_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT resource_module_namespace_module_fkey FOREIGN KEY (namespace_module_id) REFERENCES metaschema_modules_public.namespace_module (id) ON DELETE SET NULL
);

CREATE INDEX resource_module_database_id_idx ON metaschema_modules_public.resource_module ( database_id );

-- Unique constraint: one resource module per database per scope per prefix.
CREATE UNIQUE INDEX resource_module_unique_scope ON metaschema_modules_public.resource_module ( database_id, scope, prefix );

COMMIT;
