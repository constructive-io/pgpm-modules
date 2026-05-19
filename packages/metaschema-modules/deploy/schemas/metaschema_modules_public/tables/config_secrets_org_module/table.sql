-- Deploy schemas/metaschema_modules_public/tables/config_secrets_org_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.config_secrets_org_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    --
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    table_id uuid NOT NULL DEFAULT uuid_nil(),
    table_name text NOT NULL DEFAULT 'org_secrets',
    --

    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

CREATE INDEX config_secrets_org_module_database_id_idx ON metaschema_modules_public.config_secrets_org_module ( database_id );
CREATE INDEX config_secrets_org_module_schema_id_idx ON metaschema_modules_public.config_secrets_org_module ( schema_id );
CREATE INDEX config_secrets_org_module_table_id_idx ON metaschema_modules_public.config_secrets_org_module ( table_id );

COMMENT ON TABLE metaschema_modules_public.config_secrets_org_module IS 'Config row for the config_secrets_org_module, which provisions an organization-scoped encrypted key-value secrets store with manage_secrets permission and entity-membership RLS.';

COMMIT;
