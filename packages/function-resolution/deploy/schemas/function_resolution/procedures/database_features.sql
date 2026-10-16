-- Deploy schemas/function_resolution/procedures/database_features to pg

-- requires: schemas/function_resolution/schema

BEGIN;

-- database_features: one database's feature flags, each API override taking
-- precedence over the database setting, for the GraphQL server building that
-- API's schema.
--
-- routing_public.database_settings and api_settings sit behind member RLS, so
-- this is the narrow hop past them: granted to no request role, called only by
-- the platform login. No row means the database has no settings row.

CREATE FUNCTION function_resolution.database_features(database_id uuid, api_id uuid)
RETURNS TABLE (
    enable_aggregates boolean,
    enable_postgis boolean,
    enable_search boolean,
    enable_direct_uploads boolean,
    enable_presigned_uploads boolean,
    enable_many_to_many boolean,
    enable_connection_filter boolean,
    enable_ltree boolean,
    enable_llm boolean,
    enable_realtime boolean,
    enable_bulk boolean,
    enable_i18n boolean
) AS $$
BEGIN
    RETURN QUERY
    SELECT COALESCE(aps.enable_aggregates, ds.enable_aggregates),
           COALESCE(aps.enable_postgis, ds.enable_postgis),
           COALESCE(aps.enable_search, ds.enable_search),
           COALESCE(aps.enable_direct_uploads, ds.enable_direct_uploads),
           COALESCE(aps.enable_presigned_uploads, ds.enable_presigned_uploads),
           COALESCE(aps.enable_many_to_many, ds.enable_many_to_many),
           COALESCE(aps.enable_connection_filter, ds.enable_connection_filter),
           COALESCE(aps.enable_ltree, ds.enable_ltree),
           COALESCE(aps.enable_llm, ds.enable_llm),
           COALESCE(aps.enable_realtime, ds.enable_realtime),
           COALESCE(aps.enable_bulk, ds.enable_bulk),
           COALESCE(aps.enable_i18n, ds.enable_i18n)
    FROM routing_public.database_settings AS ds
    LEFT JOIN routing_public.api_settings AS aps
      ON aps.database_id = ds.database_id AND aps.api_id = database_features.api_id
    WHERE ds.database_id = database_features.database_id
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.database_features(uuid, uuid) FROM PUBLIC;

COMMIT;
