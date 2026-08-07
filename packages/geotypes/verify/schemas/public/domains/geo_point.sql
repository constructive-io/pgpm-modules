-- Verify schemas/public/domains/geo_point on pg

BEGIN;

SELECT assert_domain('public.geo_point'::regtype, 'geometry'::regtype, _constraints => 0);

ROLLBACK;
