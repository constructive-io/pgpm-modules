-- Verify schemas/status_private/procedures/upsert_achievement  on pg

BEGIN;

SELECT assert_function('status_private.upsert_achievement(uuid, text, int4)'::regprocedure);

ROLLBACK;
