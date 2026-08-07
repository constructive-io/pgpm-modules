-- Deploy schemas/metaschema_modules_public/tables/user_settings_security_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.user_settings_security_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Schema reference (populated by the insert trigger)
    schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table reference (populated by the generator)
    table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Owner table reference (resolved to users table by trigger)
    owner_table_id uuid NOT NULL DEFAULT uuid_nil(),

    table_name text NOT NULL DEFAULT 'user_settings_security',

    -- API routing (configurable per-module)
    api_name text DEFAULT NULL,

    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT owner_table_fkey FOREIGN KEY (owner_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX user_settings_security_module_unique_per_db ON metaschema_modules_public.user_settings_security_module ( database_id );
CREATE INDEX user_settings_security_module_owner_table_id_idx ON metaschema_modules_public.user_settings_security_module ( owner_table_id );
CREATE INDEX user_settings_security_module_table_id_idx ON metaschema_modules_public.user_settings_security_module ( table_id );
CREATE INDEX user_settings_security_module_schema_id_idx ON metaschema_modules_public.user_settings_security_module ( schema_id );

COMMIT;
