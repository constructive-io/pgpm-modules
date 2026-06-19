-- Verify schemas/geolite/tables/asn/table on pg

BEGIN;

SELECT verify_table ('geolite.asn');

ROLLBACK;
