-- Deploy schemas/function_resolution/procedures/email_sender_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/email_sender_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- email_sender_module_registrations: the email_sender_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.email_sender_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    entity_field text,
    public_schema text,
    provider_accounts_table_name text,
    identities_table_name text,
    site_identities_table_name text
) AS $$
SELECT
    esm.database_id,
    (esm.database_id = app_scope.platform_database_id()) AS platform_owned,
    esm.scope,
    esm.entity_field,
    ps.schema_name AS public_schema,
    accounts_t.name AS provider_accounts_table_name,
    identities_t.name AS identities_table_name,
    site_identities_t.name AS site_identities_table_name
FROM metaschema_modules_public.email_sender_module AS esm
    LEFT JOIN metaschema_public.schema ps ON ps.id = esm.schema_id
    LEFT JOIN metaschema_public.table accounts_t
    ON accounts_t.id = esm.email_provider_accounts_table_id
   AND esm.email_provider_accounts_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table identities_t
    ON identities_t.id = esm.email_identities_table_id
   AND esm.email_identities_table_id <> uuid_nil()
    LEFT JOIN metaschema_public.table site_identities_t
    ON site_identities_t.id = esm.email_site_identities_table_id
WHERE esm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.email_sender_module_registrations(uuid) FROM PUBLIC;

COMMIT;
