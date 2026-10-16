-- Deploy schemas/function_resolution/procedures/tenant_auth_entry to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/function/table

BEGIN;

-- tenant_auth_entry: one database's generated auth function names from
-- routing_public.rls_settings, for the sync gateway resolving a credential and
-- the GraphQL server's RLS module before any request identity exists.
--
-- routing_public.rls_settings and the metaschema rows it points at sit behind
-- member RLS, so this is the narrow hop past it: granted to no request role,
-- called only by the platform login on its own connection with no role switch.
-- A database with no rls_settings row, or no authenticate function, returns no
-- row; the caller answers that as an anonymous request.

CREATE FUNCTION function_resolution.tenant_auth_entry(database_id uuid)
RETURNS TABLE (
    authenticate_schema text,
    authenticate_function text,
    authenticate_strict_function text,
    role_schema text,
    current_role_function text,
    current_role_id_function text,
    current_ip_address_function text,
    current_user_agent_function text
) AS $$
BEGIN
    RETURN QUERY
    SELECT auth_schema.schema_name::text, auth_fn.name::text, auth_strict_fn.name::text,
           role_schema.schema_name::text, role_fn.name::text, role_id_fn.name::text,
           ip_fn.name::text, ua_fn.name::text
    FROM routing_public.rls_settings AS rs
    JOIN metaschema_public.schema AS auth_schema ON auth_schema.id = rs.authenticate_schema_id
    JOIN metaschema_public.function AS auth_fn ON auth_fn.id = rs.authenticate_function_id
    LEFT JOIN metaschema_public.function AS auth_strict_fn ON auth_strict_fn.id = rs.authenticate_strict_function_id
    LEFT JOIN metaschema_public.schema AS role_schema ON role_schema.id = rs.role_schema_id
    LEFT JOIN metaschema_public.function AS role_fn ON role_fn.id = rs.current_role_function_id
    LEFT JOIN metaschema_public.function AS role_id_fn ON role_id_fn.id = rs.current_role_id_function_id
    LEFT JOIN metaschema_public.function AS ip_fn ON ip_fn.id = rs.current_ip_address_function_id
    LEFT JOIN metaschema_public.function AS ua_fn ON ua_fn.id = rs.current_user_agent_function_id
    WHERE rs.database_id = tenant_auth_entry.database_id
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.tenant_auth_entry(uuid) FROM PUBLIC;

COMMIT;
