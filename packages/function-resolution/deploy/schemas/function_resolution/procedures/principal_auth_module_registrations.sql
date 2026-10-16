-- Deploy schemas/function_resolution/procedures/principal_auth_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/principal_auth_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- principal_auth_module_registrations: the principal_auth_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.principal_auth_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    sweep_expired_principals_function text,
    private_schema text
) AS $$
SELECT
    pam.database_id,
    (pam.database_id = app_scope.platform_database_id()) AS platform_owned,
    pam.sweep_expired_principals_function,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.principal_auth_module AS pam
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = pam.private_schema_id
WHERE pam.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.principal_auth_module_registrations(uuid) FROM PUBLIC;

COMMIT;
