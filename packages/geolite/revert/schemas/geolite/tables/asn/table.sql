-- Revert schemas/geolite/tables/asn/table from pg

BEGIN;

DROP TABLE geolite.asn;

COMMIT;
