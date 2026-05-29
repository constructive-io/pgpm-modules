-- Deploy schemas/geolite/procedures/lookup_asn to pg

-- requires: schemas/geolite/schema
-- requires: schemas/geolite/tables/asn/table

BEGIN;

CREATE FUNCTION geolite.lookup_asn(ip inet)
RETURNS TABLE (
  network                        cidr,
  autonomous_system_number       int,
  autonomous_system_organization text
)
AS $$
  SELECT network, autonomous_system_number, autonomous_system_organization
  FROM geolite.asn
  WHERE network >>= ip
  LIMIT 1;
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION geolite.lookup_asn(inet) IS 'Look up autonomous system number and organization for an IP address';

GRANT EXECUTE ON FUNCTION geolite.lookup_asn(inet) TO public;

COMMIT;
