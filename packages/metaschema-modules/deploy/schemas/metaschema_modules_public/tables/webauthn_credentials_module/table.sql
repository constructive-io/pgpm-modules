-- Deploy schemas/metaschema_modules_public/tables/webauthn_credentials_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.webauthn_credentials_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    table_id uuid NOT NULL DEFAULT uuid_nil(),
    owner_table_id uuid NOT NULL DEFAULT uuid_nil(),

    table_name text NOT NULL DEFAULT 'webauthn_credentials',

    -- API routing (configurable per-module)
    api_name text DEFAULT 'auth',
    private_api_name text DEFAULT NULL,

    --
    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT owner_table_fkey FOREIGN KEY (owner_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE
);

CREATE INDEX webauthn_credentials_module_database_id_idx ON metaschema_modules_public.webauthn_credentials_module ( database_id );
CREATE INDEX webauthn_credentials_module_owner_table_id_idx ON metaschema_modules_public.webauthn_credentials_module ( owner_table_id );
CREATE INDEX webauthn_credentials_module_table_id_idx ON metaschema_modules_public.webauthn_credentials_module ( table_id );
CREATE INDEX webauthn_credentials_module_private_schema_id_idx ON metaschema_modules_public.webauthn_credentials_module ( private_schema_id );
CREATE INDEX webauthn_credentials_module_schema_id_idx ON metaschema_modules_public.webauthn_credentials_module ( schema_id );

COMMENT ON TABLE metaschema_modules_public.webauthn_credentials_module IS 'Config row for the webauthn_credentials_module, which provisions the per-user WebAuthn/passkey credentials table (public key, counter, transports, device type, backup state) mirroring crypto_addresses_module. The sibling webauthn_auth_module holds RP config and the registration/sign-in challenge state.';
COMMENT ON COLUMN metaschema_modules_public.webauthn_credentials_module.private_schema_id IS 'Private schema that hosts SECURITY DEFINER helpers which write to webauthn_credentials (registration / counter-bump / delete).';

-- Tables this module generates, as opposed to tables it is handed (an
-- entity or users table it points at): the @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.webauthn_credentials_module.table_id IS '@module_table';

COMMIT;
