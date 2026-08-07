-- Verify schemas/public/domains/geography_polygon on pg

BEGIN;

SELECT assert_domain('public.geography_polygon'::regtype, 'geography'::regtype, _constraints => 0);

ROLLBACK;
