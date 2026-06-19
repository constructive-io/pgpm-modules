-- Revert schemas/geolite/tables/location/table from pg

BEGIN;

DROP TABLE geolite.location;

COMMIT;
