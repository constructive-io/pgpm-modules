-- Verify schemas/public/domains/geography_point on pg

BEGIN;

SELECT verify_domain ('public.geography_point');

ROLLBACK;
