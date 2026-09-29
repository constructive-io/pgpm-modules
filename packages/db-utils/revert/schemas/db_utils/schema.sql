-- Revert schemas/db_utils/schema from pg

BEGIN;

DROP SCHEMA db_utils;

COMMIT;
