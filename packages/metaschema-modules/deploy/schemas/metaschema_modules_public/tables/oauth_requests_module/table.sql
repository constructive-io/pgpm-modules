-- Deploy schemas/metaschema_modules_public/tables/oauth_requests_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.oauth_requests_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Scope-key column name on the generated tables. The insert trigger records
    -- database_id for database scope, entity_id for entity scopes, NULL for
    -- global tiers. Consumers read this instead of re-deriving the literal.
    entity_field text,

    -- Both tables live on the private schema and have no public counterpart:
    -- nothing outside the generated SECURITY DEFINER procedures may read a
    -- code_verifier or a link ticket, so there is no public schema to route.
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_name text,

    oauth_authorization_requests_table_id uuid NOT NULL DEFAULT uuid_nil(),
    pending_identity_links_table_id uuid NOT NULL DEFAULT uuid_nil(),

    oauth_authorization_requests_table_name text NOT NULL DEFAULT 'oauth_authorization_requests',
    pending_identity_links_table_name text NOT NULL DEFAULT 'pending_identity_links',

    scope text NOT NULL,
    prefix text NOT NULL DEFAULT '',
    entity_table_id uuid NULL,

    CONSTRAINT oauth_requests_module_db_fkey
        FOREIGN KEY (database_id)
        REFERENCES metaschema_public.database (id)
        ON DELETE CASCADE,
    CONSTRAINT oauth_requests_module_private_schema_fkey
        FOREIGN KEY (private_schema_id)
        REFERENCES metaschema_public.schema (id)
        ON DELETE CASCADE,
    CONSTRAINT oauth_requests_module_requests_table_fkey
        FOREIGN KEY (oauth_authorization_requests_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT oauth_requests_module_links_table_fkey
        FOREIGN KEY (pending_identity_links_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT oauth_requests_module_entity_table_fkey
        FOREIGN KEY (entity_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE
);

-- One install per database per scope
CREATE UNIQUE INDEX oauth_requests_module_unique_scope
    ON metaschema_modules_public.oauth_requests_module (database_id, scope);
CREATE INDEX oauth_requests_module_private_schema_id_idx ON metaschema_modules_public.oauth_requests_module ( private_schema_id );
CREATE INDEX oauth_requests_module_requests_table_id_idx ON metaschema_modules_public.oauth_requests_module ( oauth_authorization_requests_table_id );
CREATE INDEX oauth_requests_module_links_table_id_idx ON metaschema_modules_public.oauth_requests_module ( pending_identity_links_table_id );
CREATE INDEX oauth_requests_module_entity_table_id_idx ON metaschema_modules_public.oauth_requests_module ( entity_table_id );

COMMENT ON TABLE metaschema_modules_public.oauth_requests_module IS
    'Config row for the oauth_requests_module, which provisions the in-flight half of an SSO
     sign-in: the OAuth authorization requests table (state + PKCE code_verifier) and the
     pending identity links table (a verified identity parked under a single-use ticket),
     both private, plus the five SECURITY DEFINER procedures that are their only surface.
     Sibling of identity_providers_module (durable provider configuration) rather than part
     of it: this is ephemeral, purged flow state with its own retention.';

COMMIT;
