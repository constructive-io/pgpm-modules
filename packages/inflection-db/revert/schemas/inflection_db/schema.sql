-- Revert schemas/inflection_db/schema from pg

BEGIN;

DROP SCHEMA inflection_db;

COMMIT;
