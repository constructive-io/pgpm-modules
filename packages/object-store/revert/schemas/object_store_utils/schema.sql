-- Revert schemas/object_store_utils/schema from pg

BEGIN;

DROP SCHEMA object_store_utils;

COMMIT;
