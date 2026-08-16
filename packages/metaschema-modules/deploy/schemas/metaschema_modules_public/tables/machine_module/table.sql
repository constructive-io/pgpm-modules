-- Deploy schemas/metaschema_modules_public/tables/machine_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.machine_module (
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

    -- Generated table IDs (populated by the generator)
    machines_table_id uuid NOT NULL DEFAULT uuid_nil(),
    machine_sessions_table_id uuid NOT NULL DEFAULT uuid_nil(),
    machine_messages_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table names (input to the generator)
    machines_table_name text NOT NULL DEFAULT 'machines',
    machine_sessions_table_name text NOT NULL DEFAULT 'machine_sessions',
    machine_messages_table_name text NOT NULL DEFAULT 'machine_messages',

    -- Ledger partition lifecycle. Command-mode output is unbounded and
    -- time-keyed, and terminal scrollback stops being interesting long before
    -- metering does, so the default window is shorter than the usage tiers'.
    partition_interval text NOT NULL DEFAULT '1 month',
    retention text NOT NULL DEFAULT '3 months',
    premake int NOT NULL DEFAULT 2,

    -- API routing (get-or-create: if set, schema is added to this API; if NULL, no API is added)
    api_name text,
    private_api_name text,

    -- Scope: determines the security level for this module instance.
    scope text NOT NULL,

    -- Table name prefix. Auto-derived from scope by the trigger when empty.
    prefix text NOT NULL DEFAULT '',

    -- Entity table for RLS (NULL for global scopes, entity table for entity scopes)
    entity_table_id uuid NULL,

    -- Configurable security policies (NULL = use defaults based on scope).
    policies jsonb NULL,

    -- Per-table provisions overrides from blueprint config. Keys are table keys
    -- (machines, machine_sessions, machine_messages).
    provisions jsonb NULL,

    -- Default capabilities: capability names auto-granted to new members.
    default_capabilities text[] DEFAULT NULL,

    CONSTRAINT machine_module_db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT machine_module_schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT machine_module_private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT machine_module_machines_table_fkey FOREIGN KEY (machines_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT machine_module_sessions_table_fkey FOREIGN KEY (machine_sessions_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT machine_module_messages_table_fkey FOREIGN KEY (machine_messages_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT machine_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

-- One machine module per database per scope: a machine label is unique within
-- the scope that owns it, so a second install at the same scope would make
-- "which dan-macbook" ambiguous in a picker.
CREATE UNIQUE INDEX machine_module_unique_scope ON metaschema_modules_public.machine_module ( database_id, scope );
CREATE INDEX machine_module_entity_table_id_idx ON metaschema_modules_public.machine_module ( entity_table_id );
CREATE INDEX machine_module_machines_table_id_idx ON metaschema_modules_public.machine_module ( machines_table_id );
CREATE INDEX machine_module_machine_sessions_table_id_idx ON metaschema_modules_public.machine_module ( machine_sessions_table_id );
CREATE INDEX machine_module_machine_messages_table_id_idx ON metaschema_modules_public.machine_module ( machine_messages_table_id );
CREATE INDEX machine_module_private_schema_id_idx ON metaschema_modules_public.machine_module ( private_schema_id );
CREATE INDEX machine_module_schema_id_idx ON metaschema_modules_public.machine_module ( schema_id );

-- Tables this module generates, as opposed to tables it is handed: the
-- @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.machine_module.machines_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.machine_module.machine_sessions_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.machine_module.machine_messages_table_id IS '@module_table';

COMMIT;
