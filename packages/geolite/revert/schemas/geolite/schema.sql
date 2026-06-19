-- Revert schemas/geolite/schema from pg

BEGIN;

DROP SCHEMA geolite;

COMMIT;
