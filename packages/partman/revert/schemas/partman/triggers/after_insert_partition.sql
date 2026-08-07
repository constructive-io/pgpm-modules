-- Revert schemas/partman/triggers/after_insert_partition from pg

BEGIN;

DROP TRIGGER partman_after_insert_partition ON metaschema_public.partition;
DROP FUNCTION partman.tg_after_insert_partition();

COMMIT;
