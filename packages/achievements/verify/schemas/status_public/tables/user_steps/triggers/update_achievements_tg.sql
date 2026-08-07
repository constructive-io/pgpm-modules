-- Verify schemas/status_public/tables/user_steps/triggers/update_achievements_tg  on pg

BEGIN;

SELECT assert_function('status_private.tg_update_achievements_tg()'::regprocedure);
SELECT assert_trigger('status_public.user_steps'::regclass, 'update_achievements_tg', 'status_private.tg_update_achievements_tg'::regproc, 5);

ROLLBACK;
