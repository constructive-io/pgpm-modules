-- Deploy schemas/metaschema_modules_public/tables/users_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.users_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,
    --
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    table_id uuid NOT NULL DEFAULT uuid_nil(),
    table_name text NOT NULL DEFAULT 'users',
    -- 

    --
    type_table_id uuid NOT NULL DEFAULT uuid_nil(),
    type_table_name text NOT NULL DEFAULT 'role_types',
    -- 
     
    -- API routing (configurable per-module)
    api_name text DEFAULT 'auth',
    private_api_name text DEFAULT NULL,

    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT type_table_fkey FOREIGN KEY (type_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

CREATE INDEX users_module_database_id_idx ON metaschema_modules_public.users_module ( database_id );
CREATE INDEX users_module_table_id_idx ON metaschema_modules_public.users_module ( table_id );
CREATE INDEX users_module_type_table_id_idx ON metaschema_modules_public.users_module ( type_table_id );
CREATE INDEX users_module_schema_id_idx ON metaschema_modules_public.users_module ( schema_id );

-- Tables this module generates, as opposed to tables it is handed (an
-- entity or users table it points at): the @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.users_module.table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.users_module.type_table_id IS '@module_table';

COMMIT;
