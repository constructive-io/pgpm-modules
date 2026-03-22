-- Deploy schemas/public/domains/geography_point to pg

-- requires: schemas/public/schema

BEGIN;

CREATE DOMAIN geography_point AS geography (Point, 4326);
COMMENT ON DOMAIN geography_point IS E'@name pgpmInternalTypeGeographyPoint';

COMMIT;
