-- Verify schemas/partman/triggers/after_delete_partition on pg

BEGIN;

SELECT 1/count(*)
  FROM pg_trigger
  WHERE tgname = 'partman_after_delete_partition'
    AND tgrelid = 'metaschema_public.partition'::regclass;

ROLLBACK;
