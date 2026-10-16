-- Deploy schemas/function_resolution/procedures/emails_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/emails_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- emails_module_registrations: the emails_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.emails_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    public_schema text,
    emails_table_name text
) AS $$
SELECT
    em.database_id,
    (em.database_id = app_scope.platform_database_id()) AS platform_owned,
    ps.schema_name AS public_schema,
    emails_t.name AS emails_table_name
FROM metaschema_modules_public.emails_module AS em
    LEFT JOIN metaschema_public.schema ps ON ps.id = em.schema_id
    LEFT JOIN metaschema_public.table emails_t
    ON emails_t.id = em.table_id AND em.table_id <> uuid_nil()
WHERE em.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.emails_module_registrations(uuid) FROM PUBLIC;

COMMIT;
