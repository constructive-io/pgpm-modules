-- Revert schemas/geolite/procedures/lookup from pg

BEGIN;

DROP FUNCTION geolite.lookup;

COMMIT;
