-- Deploy schemas/function_resolution/procedures/webauthn_entry to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/function/table

BEGIN;

-- webauthn_entry: one database's WebAuthn relying-party settings and schema
-- names from routing_public.webauthn_settings, for the GraphQL server's
-- passkey flows.
--
-- routing_public.webauthn_settings and the metaschema rows it points at sit
-- behind member RLS, so this is the narrow hop past it: granted to no request
-- role, called only by the platform login. No row means no WebAuthn.

CREATE FUNCTION function_resolution.webauthn_entry(database_id uuid)
RETURNS TABLE (
    schema_name text,
    credentials_schema text,
    sessions_schema text,
    session_secrets_schema text,
    rp_id text,
    rp_name text,
    origin_allowlist text[],
    attestation_type text,
    require_user_verification boolean,
    resident_key text,
    challenge_expiry_seconds bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT s.schema_name::text, cred_s.schema_name::text, sess_s.schema_name::text,
           sec_s.schema_name::text, ws.rp_id, ws.rp_name, ws.origin_allowlist,
           ws.attestation_type, ws.require_user_verification, ws.resident_key,
           ws.challenge_expiry_seconds
    FROM routing_public.webauthn_settings AS ws
    LEFT JOIN metaschema_public.schema AS s ON s.id = ws.schema_id
    LEFT JOIN metaschema_public.schema AS cred_s ON cred_s.id = ws.credentials_schema_id
    LEFT JOIN metaschema_public.schema AS sess_s ON sess_s.id = ws.sessions_schema_id
    LEFT JOIN metaschema_public.schema AS sec_s ON sec_s.id = ws.session_secrets_schema_id
    WHERE ws.database_id = webauthn_entry.database_id
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.webauthn_entry(uuid) FROM PUBLIC;

COMMIT;
