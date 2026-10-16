-- Deploy schemas/function_resolution/procedures/memberships_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/memberships_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- memberships_module_registrations: the memberships_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.memberships_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    prefix text,
    entity_field text,
    memberships_table_name text,
    members_table_name text,
    grants_table_name text,
    actor_perm_check text,
    public_schema text,
    private_schema text,
    sprt_table_name text
) AS $$
SELECT
    mm.database_id,
    (mm.database_id = app_scope.platform_database_id()) AS platform_owned,
    mm.scope,
    mm.prefix,
    mm.entity_field,
    mm.memberships_table_name,
    mm.members_table_name,
    mm.grants_table_name,
    mm.actor_perm_check,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema,
    sprt_t.name AS sprt_table_name
FROM metaschema_modules_public.memberships_module AS mm
    LEFT JOIN metaschema_public.schema ps ON ps.id = mm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = mm.private_schema_id
    LEFT JOIN metaschema_public.table sprt_t ON sprt_t.id = mm.sprt_table_id
WHERE mm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.memberships_module_registrations(uuid) FROM PUBLIC;

COMMIT;
