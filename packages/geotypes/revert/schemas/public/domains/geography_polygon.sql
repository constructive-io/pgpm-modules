-- Revert schemas/public/domains/geography_polygon from pg

BEGIN;

DROP TYPE public.geography_polygon;

COMMIT;
