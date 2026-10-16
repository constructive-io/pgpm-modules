-- Deploy schemas/function_resolution/procedures/notifications_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/notifications_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- notifications_module_registrations: the notifications_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.notifications_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    has_preferences boolean,
    has_digest_metadata boolean,
    public_schema text,
    private_schema text,
    notifications_table_name text,
    preferences_table_name text,
    suppressions_table_name text
) AS $$
SELECT
    nm.database_id,
    (nm.database_id = app_scope.platform_database_id()) AS platform_owned,
    nm.has_preferences,
    nm.has_digest_metadata,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    notifications_t.name AS notifications_table_name,
    preferences_t.name AS preferences_table_name,
    suppressions_t.name AS suppressions_table_name
FROM metaschema_modules_public.notifications_module AS nm
    LEFT JOIN metaschema_public.schema ps ON ps.id = nm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = nm.private_schema_id
    LEFT JOIN metaschema_public.table notifications_t
    ON notifications_t.id = nm.notifications_table_id
    LEFT JOIN metaschema_public.table preferences_t
    ON preferences_t.id = nm.preferences_table_id
    LEFT JOIN metaschema_public.table suppressions_t
    ON suppressions_t.id = nm.suppressions_table_id
WHERE nm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.notifications_module_registrations(uuid) FROM PUBLIC;

COMMIT;
