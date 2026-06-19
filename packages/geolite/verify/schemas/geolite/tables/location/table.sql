-- Verify schemas/geolite/tables/location/table on pg

BEGIN;

SELECT verify_table ('geolite.location');

ROLLBACK;
