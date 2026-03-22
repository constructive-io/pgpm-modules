-- Verify schemas/public/domains/geo_point on pg

BEGIN;

SELECT verify_domain ('public.geo_point');

ROLLBACK;
