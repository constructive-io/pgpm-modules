-- Revert schemas/partman/triggers/after_delete_partition from pg

BEGIN;

DROP TRIGGER partman_after_delete_partition ON metaschema_public.partition;
DROP FUNCTION partman.tg_after_delete_partition();

COMMIT;
