-- Deploy schemas/function_resolution/procedures/own_bucket_location to pg

-- requires: schemas/function_resolution/schema
-- requires: pgpm-jwt-claims:schemas/jwt_private/procedures/require_database_id
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/storage_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/database/table

BEGIN;

-- One of the request database's own buckets, by row id, pinned to the
-- transaction's database claim: the ownership proof the own-bucket storage
-- operations run before anything is signed. A bucket of any other database
-- answers no row.
--
-- The object store's connection rides along, so a worker that reaches buckets
-- only by row id (a files-table job carries no declared key) can open the store
-- without a declared bucket in its bundle. It is the platform storage plane's,
-- as every module inherits it (storage_module_registrations); nothing here is
-- the tenant's own setting.
CREATE FUNCTION function_resolution.own_bucket_location(
    bucket_id uuid
) RETURNS TABLE (
    bucket_key text,
    bucket_type text,
    physical_name text,
    endpoint text,
    provider text,
    region text
) AS $$
BEGIN
    RETURN QUERY
    SELECT b.key,
           b.type,
           b.physical_name,
           psm.endpoint,
           psm.provider,
           psm.region
    FROM catalog_private.buckets b
    LEFT JOIN metaschema_modules_public.storage_module psm
      ON psm.scope = 'platform'
     AND psm.key = 'default'
     AND psm.database_id = (SELECT d.id FROM metaschema_public.database d WHERE d.platform)
    WHERE b.id = own_bucket_location.bucket_id
      AND b.database_id = jwt_private.require_database_id();
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.own_bucket_location(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION function_resolution.own_bucket_location(uuid) TO authenticated;

COMMIT;
