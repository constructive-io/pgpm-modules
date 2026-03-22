-- Verify schemas/public/domains/geo_polygon on pg

BEGIN;

SELECT verify_domain ('public.geo_polygon');

ROLLBACK;
