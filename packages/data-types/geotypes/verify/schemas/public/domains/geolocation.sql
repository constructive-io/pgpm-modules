-- Verify schemas/public/domains/geolocation on pg

BEGIN;

SELECT verify_domain ('public.location');

ROLLBACK;
