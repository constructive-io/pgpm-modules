-- Verify schemas/geolite/tables/network/table on pg

BEGIN;

SELECT verify_table ('geolite.network');

ROLLBACK;
