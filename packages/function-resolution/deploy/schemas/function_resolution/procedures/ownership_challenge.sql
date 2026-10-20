-- Deploy schemas/function_resolution/procedures/ownership_challenge to pg

-- requires: schemas/function_resolution/schema

BEGIN;

-- ownership_challenge: the pending http_01 token a hostname is being verified
-- with, for the shared static gateway answering
-- /.well-known/constructive-challenge/<token> before the hostname has any
-- route of its own.
--
-- Every scope's domain plane registers its verifications and managed domains
-- into the typed catalog, and a verification's managed_domain_id is the id of
-- its managed domain's catalog row, so one join answers for every plane.
-- Keyed by (host, token) together, so a token belonging to another domain is
-- never echoed.
--
-- It reads every tenant's challenges, so it is granted to no request role:
-- only the platform login (granted at provision) calls it, on its own
-- connection with no role switch.
CREATE FUNCTION function_resolution.ownership_challenge(
    host text,
    token text
) RETURNS text AS $$
DECLARE
    found text;
BEGIN
    SELECT v.record_value
    INTO found
    FROM catalog_private.domain_verifications AS v
    JOIN catalog_private.managed_domains AS m ON m.id = v.managed_domain_id
    WHERE m.domain = ownership_challenge.host
      AND v.method = 'http_01'
      AND v.status IN ('pending', 'checking')
      AND v.record_value = ownership_challenge.token
    LIMIT 1;
    RETURN found;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.ownership_challenge(text, text) FROM PUBLIC;

COMMIT;
