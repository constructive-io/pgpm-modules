-- Deploy schemas/metaschema_modules_public/tables/identity_providers_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.identity_providers_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    table_id uuid NOT NULL DEFAULT uuid_nil(),

    table_name text NOT NULL DEFAULT 'identity_providers',

    --
    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE
);

CREATE INDEX identity_providers_module_database_id_idx ON metaschema_modules_public.identity_providers_module ( database_id );
CREATE INDEX identity_providers_module_schema_id_idx ON metaschema_modules_public.identity_providers_module ( schema_id );
CREATE INDEX identity_providers_module_private_schema_id_idx ON metaschema_modules_public.identity_providers_module ( private_schema_id );
CREATE INDEX identity_providers_module_table_id_idx ON metaschema_modules_public.identity_providers_module ( table_id );

COMMENT ON TABLE metaschema_modules_public.identity_providers_module IS 'Config row for the identity_providers_module, which provisions a per-database identity_providers config table holding OAuth2 / OIDC (and future SAML) provider definitions: protocol kind, endpoint URLs, encrypted client secret, scopes, audience validation, PKCE, and email-handling flags. Built-in providers (google, github, apple, ...) are seeded as is_built_in=true rows; custom providers use slugs of the form custom:<slug>.';
COMMENT ON COLUMN metaschema_modules_public.identity_providers_module.private_schema_id IS 'Private schema that hosts SECURITY DEFINER admin helpers which write to identity_providers (create / update / enable / disable / rotate-secret / delete) and the per-app quota check.';

COMMIT;
