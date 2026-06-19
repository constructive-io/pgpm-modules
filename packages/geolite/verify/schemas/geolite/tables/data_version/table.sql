-- Verify schemas/geolite/tables/data_version/table on pg

BEGIN;

SELECT verify_table ('geolite.data_version');

ROLLBACK;
