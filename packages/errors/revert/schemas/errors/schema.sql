-- Revert schemas/errors/schema from pg

BEGIN;

DROP SCHEMA errors;

COMMIT;
