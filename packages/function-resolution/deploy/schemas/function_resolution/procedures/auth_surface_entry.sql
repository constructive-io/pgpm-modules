-- Deploy schemas/function_resolution/procedures/auth_surface_entry to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/identity_providers_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/connected_accounts_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/emails_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table

BEGIN;

-- auth_surface_entry: where one database's auth surface lives — the schemas
-- holding its identity sign-in procedures and its identifier views, and the
-- names of its emails and connected-accounts relations — for the GraphQL
-- server's passkey and identity flows.
--
-- The module registrations and the metaschema rows they point at sit behind
-- member RLS, so this is the narrow hop past it: names only, granted to no
-- request role, called only by the platform login. No row means the database
-- installs no identity surface.
CREATE FUNCTION function_resolution.auth_surface_entry(database_id uuid)
RETURNS TABLE (
    private_schema text,
    public_schema text,
    identifiers_public_schema text,
    emails_table text,
    connected_accounts_view text
) AS $$
SELECT
    auth_private.schema_name::text,
    auth_public.schema_name::text,
    identifiers_public.schema_name::text,
    emails.table_name,
    'user_' || connected.table_name
FROM metaschema_modules_public.identity_providers_module AS providers
    JOIN metaschema_public.schema AS auth_private ON auth_private.id = providers.private_schema_id
    JOIN metaschema_public.schema AS auth_public ON auth_public.id = providers.schema_id
    JOIN metaschema_modules_public.connected_accounts_module AS connected
    ON connected.database_id = providers.database_id
    JOIN metaschema_public.schema AS identifiers_public ON identifiers_public.id = connected.schema_id
    JOIN metaschema_modules_public.emails_module AS emails
    ON emails.database_id = providers.database_id
WHERE providers.database_id = $1
LIMIT 1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.auth_surface_entry(uuid) FROM PUBLIC;

COMMIT;
