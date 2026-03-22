-- Revert schemas/public/domains/geo_point from pg

BEGIN;

DROP TYPE public.geo_point;

COMMIT;
