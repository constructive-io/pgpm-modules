-- Verify schemas/public/domains/geography_point on pg

BEGIN;

SELECT assert_domain('public.geography_point'::regtype, 'geography'::regtype, _constraints => 0);

ROLLBACK;
