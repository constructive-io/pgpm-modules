-- Deploy schemas/metaschema_modules_public/tables/certificate_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.certificate_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Schema references (if uuid_nil, resolved from schema name or default)
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Optional schema name overrides (used when schema IDs are not provided)
    public_schema_name text,
    private_schema_name text,

    -- Generated table IDs (populated by the generator)
    certificates_table_id uuid NOT NULL DEFAULT uuid_nil(),
    certificate_domains_table_id uuid NOT NULL DEFAULT uuid_nil(),
    certificate_events_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table names (input to the generator — bare names without scope prefix).
    certificates_table_name text NOT NULL DEFAULT 'certificates',
    certificate_domains_table_name text NOT NULL DEFAULT 'certificate_domains',
    certificate_events_table_name text NOT NULL DEFAULT 'certificate_events',

    -- API routing (get-or-create: if set, schema is added to this API; if NULL, no API is added)
    api_name text,
    private_api_name text,

    -- Scope: determines the security level for this module instance.
    scope text NOT NULL DEFAULT 'platform',

    -- Table name prefix. Auto-derived from scope by the trigger when empty.
    prefix text NOT NULL DEFAULT '',

    -- Entity table for RLS
    entity_table_id uuid NULL,

    -- Configurable security policies (NULL = use defaults based on scope).
    policies jsonb NULL,

    -- Per-table provisions overrides from blueprint config.
    provisions jsonb NULL,

    -- Default permissions: permission names auto-granted to new members.
    default_permissions text[] DEFAULT NULL,

    -- Constraints
    CONSTRAINT certificate_module_db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT certificate_module_schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT certificate_module_private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT certificate_module_certs_table_fkey FOREIGN KEY (certificates_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT certificate_module_cert_domains_table_fkey FOREIGN KEY (certificate_domains_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT certificate_module_events_table_fkey FOREIGN KEY (certificate_events_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT certificate_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

CREATE INDEX certificate_module_database_id_idx ON metaschema_modules_public.certificate_module ( database_id );

-- Unique constraint: one certificate module per database per scope per prefix.
CREATE UNIQUE INDEX certificate_module_unique_scope ON metaschema_modules_public.certificate_module ( database_id, scope, prefix );

COMMIT;
