-- Revert schemas/geolite/tables/network/table from pg

BEGIN;

DROP TABLE geolite.network;

COMMIT;
