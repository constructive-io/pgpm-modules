-- Verify schemas/geolite/procedures/lookup_asn on pg

BEGIN;

SELECT verify_function ('geolite.lookup_asn');

ROLLBACK;
