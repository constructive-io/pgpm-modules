-- Revert schemas/public/domains/geography_point from pg

BEGIN;

DROP TYPE public.geography_point;

COMMIT;
