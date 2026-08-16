-- Deploy schemas/metaschema_modules_public/tables/email_sender_module/table to pg

-- requires: schemas/metaschema_modules_public/schema
-- requires: schemas/metaschema_modules_public/tables/site_surface_module/table

BEGIN;

CREATE TABLE metaschema_modules_public.email_sender_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Scope-key column name on the generated tables. The insert trigger records
    -- database_id for database scope, entity_id for entity scopes, NULL for
    -- global tiers. Consumers read this instead of re-deriving the literal.
    entity_field text,

    -- Schema reference (uuid_nil is resolved from schema names/defaults).
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    public_schema_name text,

    -- Generated table IDs. The site binding table is only generated when a
    -- site_surface_module exists at the same scope, so it stays nullable.
    email_provider_accounts_table_id uuid NOT NULL DEFAULT uuid_nil(),
    email_identities_table_id uuid NOT NULL DEFAULT uuid_nil(),
    email_site_identities_table_id uuid NULL,

    -- Bare table names; the trigger prepends the scope prefix.
    email_provider_accounts_table_name text NOT NULL DEFAULT 'email_provider_accounts',
    email_identities_table_name text NOT NULL DEFAULT 'email_identities',
    email_site_identities_table_name text NOT NULL DEFAULT 'email_site_identities',

    -- Site surface at the exact same scope, when one exists.
    site_surface_module_id uuid,

    -- API routing (optional administrative CRUD surface).
    api_name text,
    private_api_name text,

    scope text NOT NULL,
    prefix text NOT NULL DEFAULT '',
    entity_table_id uuid NULL,

    policies jsonb NULL,
    provisions jsonb NULL,
    default_capabilities text[] DEFAULT NULL,

    CONSTRAINT email_sender_module_db_fkey
        FOREIGN KEY (database_id)
        REFERENCES metaschema_public.database (id)
        ON DELETE CASCADE,
    CONSTRAINT email_sender_module_schema_fkey
        FOREIGN KEY (schema_id)
        REFERENCES metaschema_public.schema (id)
        ON DELETE CASCADE,
    CONSTRAINT email_sender_module_provider_accounts_table_fkey
        FOREIGN KEY (email_provider_accounts_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT email_sender_module_identities_table_fkey
        FOREIGN KEY (email_identities_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT email_sender_module_site_identities_table_fkey
        FOREIGN KEY (email_site_identities_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT email_sender_module_site_surface_module_fkey
        FOREIGN KEY (site_surface_module_id)
        REFERENCES metaschema_modules_public.site_surface_module (id)
        ON DELETE CASCADE,
    CONSTRAINT email_sender_module_entity_table_fkey
        FOREIGN KEY (entity_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE
);

CREATE UNIQUE INDEX email_sender_module_unique_scope
    ON metaschema_modules_public.email_sender_module (database_id, scope);
CREATE INDEX email_sender_module_schema_id_idx ON metaschema_modules_public.email_sender_module ( schema_id );
CREATE INDEX email_sender_module_provider_accounts_table_id_idx ON metaschema_modules_public.email_sender_module ( email_provider_accounts_table_id );
CREATE INDEX email_sender_module_identities_table_id_idx ON metaschema_modules_public.email_sender_module ( email_identities_table_id );
CREATE INDEX email_sender_module_site_identities_table_id_idx ON metaschema_modules_public.email_sender_module ( email_site_identities_table_id );
CREATE INDEX email_sender_module_site_surface_module_id_idx ON metaschema_modules_public.email_sender_module ( site_surface_module_id );
CREATE INDEX email_sender_module_entity_table_id_idx ON metaschema_modules_public.email_sender_module ( entity_table_id );

-- Tables this module generates, as opposed to tables it is handed (an
-- entity or users table it points at): the @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.email_sender_module.email_identities_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.email_sender_module.email_provider_accounts_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.email_sender_module.email_site_identities_table_id IS '@module_table';

COMMIT;
