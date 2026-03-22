-- Revert schemas/public/domains/geo_polygon from pg

BEGIN;

DROP TYPE public.geo_polygon;

COMMIT;
