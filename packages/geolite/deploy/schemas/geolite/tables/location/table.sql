-- Deploy schemas/geolite/tables/location/table to pg

-- requires: schemas/geolite/schema

BEGIN;

CREATE TABLE geolite.location (
  id                      uuid    PRIMARY KEY DEFAULT uuidv7(),
  geoname_id              int     NOT NULL,
  locale_code             text    NOT NULL,
  continent_code          text,
  continent_name          text,
  country_iso_code        text,
  country_name            text,
  subdivision_1_iso_code  text,
  subdivision_1_name      text,
  subdivision_2_iso_code  text,
  subdivision_2_name      text,
  city_name               text,
  metro_code              int,
  time_zone               text,
  is_in_european_union    bool    NOT NULL DEFAULT false,
  UNIQUE (geoname_id, locale_code)
);

COMMENT ON TABLE geolite.location IS 'GeoLite2 location metadata keyed by geoname_id and locale';
COMMENT ON COLUMN geolite.location.geoname_id IS 'GeoNames identifier; join key from geolite.network';
COMMENT ON COLUMN geolite.location.locale_code IS 'Locale for localized names (e.g. en, zh-CN, ja)';
COMMENT ON COLUMN geolite.location.country_iso_code IS 'ISO 3166-1 alpha-2 country code';
COMMENT ON COLUMN geolite.location.time_zone IS 'IANA time zone identifier';

GRANT SELECT ON TABLE geolite.location TO public;

COMMIT;
