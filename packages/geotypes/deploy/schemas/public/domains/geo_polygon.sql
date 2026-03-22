-- Deploy schemas/public/domains/geo_polygon to pg

-- requires: schemas/public/schema

BEGIN;

CREATE DOMAIN geo_polygon AS geometry (Polygon, 4326);
COMMENT ON DOMAIN geo_polygon IS E'@name pgpmInternalTypeGeoPolygon';

COMMIT;
