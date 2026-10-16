-- Deploy schemas/function_resolution/procedures/file_ref_field_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/file_ref_field/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/field/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- file_ref_field_registrations: the file_ref_field rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.file_ref_field_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    id uuid,
    storage_module_id uuid,
    schema_name text,
    table_name text,
    field_name text,
    bucket_key text,
    bucket_tags text[],
    is_public boolean,
    enforce_fk boolean
) AS $$
SELECT
    frf.database_id,
    (frf.database_id = app_scope.platform_database_id()) AS platform_owned,
    frf.id,
    frf.storage_module_id,
    s.schema_name,
    t.name AS table_name,
    f.name AS field_name,
    frf.bucket_key,
    frf.bucket_tags::text[] AS bucket_tags,
    frf.is_public,
    frf.enforce_fk
FROM metaschema_modules_public.file_ref_field AS frf
    JOIN metaschema_public.field f ON f.id = frf.field_id
    JOIN metaschema_public.table t ON t.id = frf.table_id
    JOIN metaschema_public.schema s ON s.id = t.schema_id
WHERE frf.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.file_ref_field_registrations(uuid) FROM PUBLIC;

COMMIT;
