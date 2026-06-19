-- Revert schemas/geolite/tables/data_version/table from pg

BEGIN;

DROP TABLE geolite.data_version;

COMMIT;
