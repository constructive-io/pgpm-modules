-- Deploy schemas/function_resolution/procedures/storage_file_ref_field to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/file_ref_field/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/field/table
-- requires: pgpm-jwt-claims:schemas/jwt_private/procedures/require_database_id
-- requires: schemas/function_resolution/procedures/file_ref_field_registrations

BEGIN;

-- storage_file_ref_field: the file-ref binding of one physical column in the
-- request's own database, read on the request's anonymous/authenticated lane.
--
-- The registry records field ids, the GraphQL layer knows (schema, table,
-- column), and only metaschema maps one to the other, which RLS hides from a
-- tenant's end users. The database is the caller's own
-- jwt.claims.database_id (missing raises), never an argument.
CREATE FUNCTION function_resolution.storage_file_ref_field(
    schema_name text,
    table_name text,
    field_name text
) RETURNS TABLE (
    id uuid,
    storage_module_id uuid,
    bucket_key text,
    bucket_tags text[],
    is_public boolean,
    enforce_fk boolean
) AS $$
    SELECT
        r.id,
        r.storage_module_id,
        r.bucket_key,
        r.bucket_tags,
        r.is_public,
        r.enforce_fk
    FROM function_resolution.file_ref_field_registrations(jwt_private.require_database_id()) AS r
    WHERE r.schema_name = storage_file_ref_field.schema_name
      AND r.table_name = storage_file_ref_field.table_name
      AND r.field_name = storage_file_ref_field.field_name
    LIMIT 1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.storage_file_ref_field(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION function_resolution.storage_file_ref_field(text, text, text) TO authenticated, anonymous;

COMMIT;
