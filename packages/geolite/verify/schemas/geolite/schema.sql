-- Verify schemas/geolite/schema on pg

BEGIN;

SELECT verify_schema ('geolite');

ROLLBACK;
