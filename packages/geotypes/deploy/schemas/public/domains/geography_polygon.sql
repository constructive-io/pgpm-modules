-- Deploy schemas/public/domains/geography_polygon to pg

-- requires: schemas/public/schema

BEGIN;

CREATE DOMAIN geography_polygon AS geography (Polygon, 4326);
COMMENT ON DOMAIN geography_polygon IS E'@name pgpmInternalTypeGeographyPolygon';

COMMIT;
