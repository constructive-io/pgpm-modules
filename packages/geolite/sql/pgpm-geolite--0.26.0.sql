\echo Use "CREATE EXTENSION pgpm-geolite" to load this file. \quit
CREATE SCHEMA geolite;

CREATE TABLE geolite.network (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  network cidr NOT NULL,
  geoname_id int,
  registered_country_geoname_id int,
  represented_country_geoname_id int,
  is_anonymous_proxy bool DEFAULT false,
  is_satellite_provider bool DEFAULT false,
  postal_code text,
  latitude numeric,
  longitude numeric,
  accuracy_radius int,
  is_anycast bool DEFAULT false
);

COMMENT ON TABLE geolite.network IS 'GeoLite2 CIDR network blocks mapped to geoname locations and coordinates';

COMMENT ON COLUMN geolite.network.network IS 'IPv4 or IPv6 CIDR block';

COMMENT ON COLUMN geolite.network.geoname_id IS 'Foreign key to geolite.location for the resolved location';

COMMENT ON COLUMN geolite.network.latitude IS 'Approximate latitude of the network block centroid';

COMMENT ON COLUMN geolite.network.longitude IS 'Approximate longitude of the network block centroid';

COMMENT ON COLUMN geolite.network.accuracy_radius IS 'Accuracy radius in kilometers around lat/long';

CREATE INDEX network_cidr_gist_idx ON geolite.network USING gist (network inet_ops);

GRANT SELECT ON geolite.network TO PUBLIC;

CREATE TABLE geolite.location (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  geoname_id int NOT NULL,
  locale_code text NOT NULL,
  continent_code text,
  continent_name text,
  country_iso_code text,
  country_name text,
  subdivision_1_iso_code text,
  subdivision_1_name text,
  subdivision_2_iso_code text,
  subdivision_2_name text,
  city_name text,
  metro_code int,
  time_zone text,
  is_in_european_union bool NOT NULL DEFAULT false,
  UNIQUE (geoname_id, locale_code)
);

COMMENT ON TABLE geolite.location IS 'GeoLite2 location metadata keyed by geoname_id and locale';

COMMENT ON COLUMN geolite.location.geoname_id IS 'GeoNames identifier; join key from geolite.network';

COMMENT ON COLUMN geolite.location.locale_code IS 'Locale for localized names (e.g. en, zh-CN, ja)';

COMMENT ON COLUMN geolite.location.country_iso_code IS 'ISO 3166-1 alpha-2 country code';

COMMENT ON COLUMN geolite.location.time_zone IS 'IANA time zone identifier';

GRANT SELECT ON geolite.location TO PUBLIC;

CREATE TABLE geolite.asn (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  network cidr NOT NULL,
  autonomous_system_number int NOT NULL,
  autonomous_system_organization text
);

COMMENT ON TABLE geolite.asn IS 'GeoLite2 ASN database mapping CIDR blocks to autonomous system numbers';

COMMENT ON COLUMN geolite.asn.network IS 'IPv4 or IPv6 CIDR block';

COMMENT ON COLUMN geolite.asn.autonomous_system_number IS 'BGP autonomous system number';

COMMENT ON COLUMN geolite.asn.autonomous_system_organization IS 'Organization name for the autonomous system';

CREATE INDEX asn_cidr_gist_idx ON geolite.asn USING gist (network inet_ops);

GRANT SELECT ON geolite.asn TO PUBLIC;

CREATE TABLE geolite.data_version (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  version text NOT NULL,
  loaded_at timestamptz NOT NULL DEFAULT now(),
  source_url text
);

COMMENT ON TABLE geolite.data_version IS 'Tracks which GeoLite2 release is currently loaded';

COMMENT ON COLUMN geolite.data_version.version IS 'GeoLite2 release version or date tag';

COMMENT ON COLUMN geolite.data_version.loaded_at IS 'Timestamp when data was last loaded';

COMMENT ON COLUMN geolite.data_version.source_url IS 'URL the data was downloaded from';

GRANT SELECT ON geolite.data_version TO PUBLIC;

CREATE FUNCTION geolite.lookup(ip inet) RETURNS TABLE ( network cidr, country_iso_code text, country_name text, subdivision_1_name text, city_name text, postal_code text, latitude numeric, longitude numeric, accuracy_radius int, time_zone text, continent_code text, is_in_european_union bool ) AS $EOFCODE$
  SELECT
    n.network,
    l.country_iso_code,
    l.country_name,
    l.subdivision_1_name,
    l.city_name,
    n.postal_code,
    n.latitude,
    n.longitude,
    n.accuracy_radius,
    l.time_zone,
    l.continent_code,
    l.is_in_european_union
  FROM geolite.network n
  LEFT JOIN geolite.location l
    ON n.geoname_id = l.geoname_id
    AND l.locale_code = 'en'
  WHERE n.network >>= ip
  LIMIT 1;
$EOFCODE$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION geolite.lookup(inet) IS 'Look up city/country geolocation data for an IP address';

GRANT EXECUTE ON FUNCTION geolite.lookup(inet) TO PUBLIC;

CREATE FUNCTION geolite.lookup_asn(ip inet) RETURNS TABLE ( network cidr, autonomous_system_number int, autonomous_system_organization text ) AS $EOFCODE$
  SELECT network, autonomous_system_number, autonomous_system_organization
  FROM geolite.asn
  WHERE network >>= ip
  LIMIT 1;
$EOFCODE$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION geolite.lookup_asn(inet) IS 'Look up autonomous system number and organization for an IP address';

GRANT EXECUTE ON FUNCTION geolite.lookup_asn(inet) TO PUBLIC;