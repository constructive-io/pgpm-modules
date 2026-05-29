-- Deploy schemas/geolite/tables/network/table to pg

-- requires: schemas/geolite/schema

BEGIN;

CREATE TABLE geolite.network (
  id                             uuid    PRIMARY KEY DEFAULT uuidv7(),
  network                        cidr    NOT NULL,
  geoname_id                     int,
  registered_country_geoname_id  int,
  represented_country_geoname_id int,
  is_anonymous_proxy             bool    DEFAULT false,
  is_satellite_provider          bool    DEFAULT false,
  postal_code                    text,
  latitude                       numeric,
  longitude                      numeric,
  accuracy_radius                int,
  is_anycast                     bool    DEFAULT false
);

COMMENT ON TABLE geolite.network IS 'GeoLite2 CIDR network blocks mapped to geoname locations and coordinates';
COMMENT ON COLUMN geolite.network.network IS 'IPv4 or IPv6 CIDR block';
COMMENT ON COLUMN geolite.network.geoname_id IS 'Foreign key to geolite.location for the resolved location';
COMMENT ON COLUMN geolite.network.latitude IS 'Approximate latitude of the network block centroid';
COMMENT ON COLUMN geolite.network.longitude IS 'Approximate longitude of the network block centroid';
COMMENT ON COLUMN geolite.network.accuracy_radius IS 'Accuracy radius in kilometers around lat/long';

CREATE INDEX network_cidr_gist_idx
  ON geolite.network USING gist (network inet_ops);

GRANT SELECT ON TABLE geolite.network TO public;

COMMIT;
