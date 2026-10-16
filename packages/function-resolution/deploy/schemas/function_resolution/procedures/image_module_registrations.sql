-- Deploy schemas/function_resolution/procedures/image_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/image_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- image_module_registrations: the image_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: owner_database_id answers a database's own
-- instances, surface_scope a shared surface across databases, and NULL leaves that
-- side unfiltered. Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.image_module_registrations(owner_database_id uuid, surface_scope text DEFAULT NULL)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    prefix text,
    entity_field text,
    images_table_name text,
    image_grants_table_name text,
    registries_table_name text,
    registry_grants_table_name text,
    public_schema text,
    private_schema text
) AS $$
SELECT
    imgm.database_id,
    (imgm.database_id = app_scope.platform_database_id()) AS platform_owned,
    imgm.scope,
    imgm.prefix,
    imgm.entity_field,
    imgm.images_table_name,
    imgm.image_grants_table_name,
    imgm.registries_table_name,
    imgm.registry_grants_table_name,
    ps.schema_name AS public_schema,
    pvs.schema_name AS private_schema
FROM metaschema_modules_public.image_module AS imgm
    LEFT JOIN metaschema_public.schema ps ON ps.id = imgm.schema_id
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = imgm.private_schema_id
WHERE ($1 IS NULL OR imgm.database_id = $1)
  AND ($2 IS NULL OR imgm.scope = $2)
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.image_module_registrations(uuid, text) FROM PUBLIC;

COMMIT;
