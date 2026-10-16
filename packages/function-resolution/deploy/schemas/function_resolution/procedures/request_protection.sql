-- Deploy schemas/function_resolution/procedures/request_protection to pg

-- requires: schemas/function_resolution/schema

BEGIN;

-- request_protection: one database's raw request bounds and the API's raw
-- overrides, side by side, for the GraphQL server to combine and clamp against
-- the platform ceilings in code.
--
-- routing_public.database_settings and api_settings sit behind member RLS, so
-- this is the narrow hop past them: granted to no request role, called only by
-- the platform login. No row means the database has no settings row.

CREATE FUNCTION function_resolution.request_protection(database_id uuid, api_id uuid)
RETURNS TABLE (
    db_statement_timeout_ms bigint,
    db_idle_in_transaction_timeout_ms bigint,
    db_lock_timeout_ms bigint,
    db_max_concurrent_requests int,
    db_max_queue_wait_ms int,
    db_rate_limit_rpm int,
    db_rate_limit_burst int,
    db_max_query_depth int,
    db_max_query_cost int,
    db_max_page_size int,
    db_max_request_bytes int,
    db_enable_introspection boolean,
    api_statement_timeout_ms bigint,
    api_idle_in_transaction_timeout_ms bigint,
    api_lock_timeout_ms bigint,
    api_max_concurrent_requests int,
    api_max_queue_wait_ms int,
    api_rate_limit_rpm int,
    api_rate_limit_burst int,
    api_max_query_depth int,
    api_max_query_cost int,
    api_max_page_size int,
    api_max_request_bytes int,
    api_enable_introspection boolean
) AS $$
BEGIN
    RETURN QUERY
    SELECT ds.statement_timeout_ms,
           ds.idle_in_transaction_timeout_ms,
           ds.lock_timeout_ms,
           ds.max_concurrent_requests,
           ds.max_queue_wait_ms,
           ds.rate_limit_rpm,
           ds.rate_limit_burst,
           ds.max_query_depth,
           ds.max_query_cost,
           ds.max_page_size,
           ds.max_request_bytes,
           ds.enable_introspection,
           aps.statement_timeout_ms,
           aps.idle_in_transaction_timeout_ms,
           aps.lock_timeout_ms,
           aps.max_concurrent_requests,
           aps.max_queue_wait_ms,
           aps.rate_limit_rpm,
           aps.rate_limit_burst,
           aps.max_query_depth,
           aps.max_query_cost,
           aps.max_page_size,
           aps.max_request_bytes,
           aps.enable_introspection
    FROM routing_public.database_settings AS ds
    LEFT JOIN routing_public.api_settings AS aps
      ON aps.database_id = ds.database_id AND aps.api_id = request_protection.api_id
    WHERE ds.database_id = request_protection.database_id
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.request_protection(uuid, uuid) FROM PUBLIC;

COMMIT;
