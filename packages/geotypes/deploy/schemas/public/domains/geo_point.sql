-- Deploy schemas/public/domains/geo_point to pg

-- requires: schemas/public/schema

BEGIN;

CREATE DOMAIN geo_point AS geometry (Point, 4326);
COMMENT ON DOMAIN geo_point IS E'@name pgpmInternalTypeGeoPoint';

COMMIT;
