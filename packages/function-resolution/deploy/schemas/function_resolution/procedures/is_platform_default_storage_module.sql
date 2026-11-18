-- Deploy schemas/function_resolution/procedures/is_platform_default_storage_module to pg

-- requires: schemas/function_resolution/schema
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/storage_module/table

BEGIN;

-- Fail-closed proof for the only module allowed to request a global CORS
-- inheritance fan-out. The trigger and explicit repair enqueue both use this
-- canonical platform/default identity.
CREATE FUNCTION function_resolution.is_platform_default_storage_module(
    storage_module_id uuid
) RETURNS boolean AS $$
SELECT EXISTS (
    SELECT 1
      FROM metaschema_modules_public.storage_module sm
     WHERE sm.id = is_platform_default_storage_module.storage_module_id
       AND sm.database_id = app_scope.platform_database_id()
       AND sm.scope = 'platform'
       AND sm.key = 'default'
)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.is_platform_default_storage_module(uuid) FROM PUBLIC;

COMMIT;
