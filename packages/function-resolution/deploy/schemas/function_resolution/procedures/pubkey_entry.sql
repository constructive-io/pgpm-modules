-- Deploy schemas/function_resolution/procedures/pubkey_entry to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/function/table

BEGIN;

-- pubkey_entry: one database's key-auth schema, network and function names
-- from routing_public.pubkey_settings, for the GraphQL server's key sign-in.
--
-- routing_public.pubkey_settings and the metaschema rows it points at sit
-- behind member RLS, so this is the narrow hop past it: granted to no request
-- role, called only by the platform login. No row means no key auth.

CREATE FUNCTION function_resolution.pubkey_entry(database_id uuid)
RETURNS TABLE (
    schema_name text,
    crypto_network text,
    sign_up_with_key text,
    sign_in_request_challenge text,
    sign_in_record_failure text,
    sign_in_with_challenge text
) AS $$
BEGIN
    RETURN QUERY
    SELECT s.schema_name::text, ps.crypto_network, sign_up_fn.name::text,
           sign_in_req_fn.name::text, sign_in_fail_fn.name::text, sign_in_fn.name::text
    FROM routing_public.pubkey_settings AS ps
    LEFT JOIN metaschema_public.schema AS s ON s.id = ps.schema_id
    LEFT JOIN metaschema_public.function AS sign_up_fn ON sign_up_fn.id = ps.sign_up_with_key_function_id
    LEFT JOIN metaschema_public.function AS sign_in_req_fn ON sign_in_req_fn.id = ps.sign_in_request_challenge_function_id
    LEFT JOIN metaschema_public.function AS sign_in_fail_fn ON sign_in_fail_fn.id = ps.sign_in_record_failure_function_id
    LEFT JOIN metaschema_public.function AS sign_in_fn ON sign_in_fn.id = ps.sign_in_with_challenge_function_id
    WHERE ps.database_id = pubkey_entry.database_id
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.pubkey_entry(uuid) FROM PUBLIC;

COMMIT;
