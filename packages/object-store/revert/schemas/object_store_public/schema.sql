-- Revert schemas/object_store_public/schema from pg

BEGIN;

DROP SCHEMA object_store_public;

COMMIT;
