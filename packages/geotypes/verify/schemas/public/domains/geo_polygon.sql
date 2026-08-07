-- Verify schemas/public/domains/geo_polygon on pg

BEGIN;

SELECT assert_domain('public.geo_polygon'::regtype, 'geometry'::regtype, _constraints => 0);

ROLLBACK;
