-- Verify schemas/status_private/procedures/status_triggers  on pg

BEGIN;

SELECT assert_function('status_private.tg_achievement()'::regprocedure);
SELECT assert_function('status_private.tg_achievement_toggle()'::regprocedure);
SELECT assert_function('status_private.tg_achievement_boolean()'::regprocedure);
SELECT assert_function('status_private.tg_achievement_toggle_boolean()'::regprocedure);

ROLLBACK;
