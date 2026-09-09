\echo Use "CREATE EXTENSION pgpm-geo-types" to load this file. \quit
CREATE DOMAIN geo_point AS geometry(point, 4326);

COMMENT ON DOMAIN geo_point IS '@name pgpmInternalTypeGeoPoint';

CREATE DOMAIN geo_polygon AS geometry(polygon, 4326);

COMMENT ON DOMAIN geo_polygon IS '@name pgpmInternalTypeGeoPolygon';

CREATE DOMAIN geography_point AS geography(point, 4326);

COMMENT ON DOMAIN geography_point IS '@name pgpmInternalTypeGeographyPoint';

CREATE DOMAIN geography_polygon AS geography(polygon, 4326);

COMMENT ON DOMAIN geography_polygon IS '@name pgpmInternalTypeGeographyPolygon';