-- Deploy schemas/metaschema_modules_public/tables/i18n_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.i18n_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Schema references (populated by the insert trigger)
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Settings table (populated by the generator)
    settings_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- API routing (configurable per-module)
    api_name text DEFAULT NULL,
    private_api_name text DEFAULT NULL,

    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT settings_table_fkey FOREIGN KEY (settings_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX i18n_module_unique_per_db ON metaschema_modules_public.i18n_module ( database_id );
CREATE INDEX i18n_module_settings_table_id_idx ON metaschema_modules_public.i18n_module ( settings_table_id );
CREATE INDEX i18n_module_private_schema_id_idx ON metaschema_modules_public.i18n_module ( private_schema_id );
CREATE INDEX i18n_module_schema_id_idx ON metaschema_modules_public.i18n_module ( schema_id );

COMMIT;
