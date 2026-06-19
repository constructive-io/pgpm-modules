-- Revert schemas/geolite/procedures/lookup_asn from pg

BEGIN;

DROP FUNCTION geolite.lookup_asn;

COMMIT;
