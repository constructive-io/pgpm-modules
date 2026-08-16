-- Deploy schemas/metaschema_modules_public/tables/scope_types_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

-- Config row for the scope type projection: the global table that records, for
-- every scope of every logical database, which scope encloses it.
--
-- One row per POSTGRES database, provisioned once from the platform database's
-- plane pass beside catalog_module — the typed catalog's shape. A plane read by
-- static SQL cannot be generated per logical database: metaschema prefixes each
-- generated schema with the owning database's schema_hash, and no static reader
-- can name a hashed schema.
CREATE TABLE metaschema_modules_public.scope_types_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,
    --
    schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Schema name override: when set, the trigger uses this instead of the
    -- 'scope_private' default.
    private_schema_name text,

    scope_types_table_id uuid NOT NULL DEFAULT uuid_nil(),

    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT scope_types_table_fkey FOREIGN KEY (scope_types_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,

    CONSTRAINT scope_types_module_unique UNIQUE (database_id)
);

CREATE INDEX scope_types_module_database_id_idx ON metaschema_modules_public.scope_types_module ( database_id );
CREATE INDEX scope_types_module_schema_id_idx ON metaschema_modules_public.scope_types_module ( schema_id );
CREATE INDEX scope_types_module_scope_types_table_id_idx ON metaschema_modules_public.scope_types_module ( scope_types_table_id );

-- Tables this module generates, as opposed to tables it is handed (an
-- entity or users table it points at): the @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.scope_types_module.scope_types_table_id IS '@module_table';

COMMIT;
