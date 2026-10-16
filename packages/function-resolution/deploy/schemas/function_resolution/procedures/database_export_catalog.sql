-- Deploy schemas/function_resolution/procedures/database_export_catalog to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-schema:schemas/metaschema_public/tables/database/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table

BEGIN;

-- database_export_catalog: the database and schema rows the export lane names a
-- bundle after. The NOBYPASSRLS platform login sees neither catalog row under
-- member RLS, so this SECURITY DEFINER reader is its way in: one database's name
-- and its schemas, nothing else. Granted to the platform login alone (fun
-- platform COMPONENT_GRANTS); not exposed through GraphQL.
CREATE FUNCTION function_resolution.database_export_catalog(database_id uuid)
RETURNS TABLE (
    database_name text,
    schema_id uuid,
    schema_label text,
    schema_name text
) AS $$
SELECT d.name::text, s.id, s.name::text, s.schema_name::text
FROM metaschema_public.database AS d
    LEFT JOIN metaschema_public.schema AS s ON s.database_id = d.id
WHERE d.id = $1
ORDER BY s.schema_name
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.database_export_catalog(uuid) FROM PUBLIC;

COMMIT;
