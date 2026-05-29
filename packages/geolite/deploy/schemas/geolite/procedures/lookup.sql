-- Deploy schemas/geolite/procedures/lookup to pg

-- requires: schemas/geolite/schema
-- requires: schemas/geolite/tables/network/table
-- requires: schemas/geolite/tables/location/table

BEGIN;

CREATE FUNCTION geolite.lookup(ip inet)
RETURNS TABLE (
  network              cidr,
  country_iso_code     text,
  country_name         text,
  subdivision_1_name   text,
  city_name            text,
  postal_code          text,
  latitude             numeric,
  longitude            numeric,
  accuracy_radius      int,
  time_zone            text,
  continent_code       text,
  is_in_european_union bool
)
AS $$
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
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION geolite.lookup(inet) IS 'Look up city/country geolocation data for an IP address';

GRANT EXECUTE ON FUNCTION geolite.lookup(inet) TO public;

COMMIT;
