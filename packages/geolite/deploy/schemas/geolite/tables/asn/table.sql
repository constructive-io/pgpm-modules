-- Deploy schemas/geolite/tables/asn/table to pg

-- requires: schemas/geolite/schema

BEGIN;

CREATE TABLE geolite.asn (
  id                             uuid    PRIMARY KEY DEFAULT uuidv7(),
  network                        cidr    NOT NULL,
  autonomous_system_number       int     NOT NULL,
  autonomous_system_organization text
);

COMMENT ON TABLE geolite.asn IS 'GeoLite2 ASN database mapping CIDR blocks to autonomous system numbers';
COMMENT ON COLUMN geolite.asn.network IS 'IPv4 or IPv6 CIDR block';
COMMENT ON COLUMN geolite.asn.autonomous_system_number IS 'BGP autonomous system number';
COMMENT ON COLUMN geolite.asn.autonomous_system_organization IS 'Organization name for the autonomous system';

CREATE INDEX asn_cidr_gist_idx
  ON geolite.asn USING gist (network inet_ops);

GRANT SELECT ON TABLE geolite.asn TO public;

COMMIT;
