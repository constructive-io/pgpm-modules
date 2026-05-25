-- Deploy schemas/metaschema_modules_public/tables/namespace_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.namespace_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Schema references (if uuid_nil, resolved from schema name or default)
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Optional schema name overrides (used when schema IDs are not provided)
    public_schema_name text,
    private_schema_name text,

    -- Generated table ID (populated by the generator)
    namespaces_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table name (input to the generator)
    namespaces_table_name text NOT NULL DEFAULT 'namespaces',

    -- API routing (get-or-create: if set, schema is added to this API; if NULL, no API is added)
    api_name text,
    private_api_name text,

    -- Multi-tenant namespace identity
    membership_type int DEFAULT NULL,              -- NULL = database-root (AuthzMembership via app_sprt), non-NULL = entity-scoped (AuthzEntityMembership)

    -- Entity table for RLS (NULL for app-level namespaces, entity table for entity-scoped namespaces)
    entity_table_id uuid NULL,

    -- Configurable security policies (NULL = use defaults based on membership_type).
    -- When provided, replaces the default policy set in apply_namespace_security.
    -- Accepts a JSON array of policy objects:
    --   {"$type": "AuthzEntityMembership", "privileges": ["select", "update"], "data": {...}}
    policies jsonb NULL,

    -- Constraints
    CONSTRAINT namespace_module_db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT namespace_module_schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT namespace_module_private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT namespace_module_namespaces_table_fkey FOREIGN KEY (namespaces_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT namespace_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

CREATE INDEX namespace_module_database_id_idx ON metaschema_modules_public.namespace_module ( database_id );

-- Unique constraint on (database_id, membership_type) using COALESCE to handle NULLs.
-- NULL membership_type = app-level, non-NULL = entity-scoped.
-- Only one namespace module per scope (unlike storage_module which has storage_key).
CREATE UNIQUE INDEX namespace_module_unique_scope ON metaschema_modules_public.namespace_module ( database_id, COALESCE(membership_type, -1) );

COMMIT;
