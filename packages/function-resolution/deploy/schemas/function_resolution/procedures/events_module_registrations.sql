-- Deploy schemas/function_resolution/procedures/events_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/events_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- events_module_registrations: the events_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.events_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    private_schema text,
    record_event text,
    expire_grants text
) AS $$
SELECT
    em.database_id,
    (em.database_id = app_scope.platform_database_id()) AS platform_owned,
    em.scope,
    pvs.schema_name AS private_schema,
    em.record_event,
    em.expire_grants
FROM metaschema_modules_public.events_module AS em
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = em.private_schema_id
WHERE em.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.events_module_registrations(uuid) FROM PUBLIC;

COMMIT;
