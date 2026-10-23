-- Revert schemas/reserved_names/schema from pg

BEGIN;

DROP SCHEMA reserved_names;

COMMIT;
