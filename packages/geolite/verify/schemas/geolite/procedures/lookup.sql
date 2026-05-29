-- Verify schemas/geolite/procedures/lookup on pg

BEGIN;

SELECT verify_function ('geolite.lookup');

ROLLBACK;
