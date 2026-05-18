-- Revert schemas/object_store_private/schema from pg

BEGIN;

DROP SCHEMA object_store_private;

COMMIT;
