-- Verify schemas/public/domains/geography_polygon on pg

BEGIN;

SELECT verify_domain ('public.geography_polygon');

ROLLBACK;
