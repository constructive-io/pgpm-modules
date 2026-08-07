-- Verify schemas/status_public/tables/user_achievements/policies/user_achievements_policy  on pg

BEGIN;

SELECT assert_policy('status_public.user_achievements'::regclass, 'can_select_user_achievements', 'select', true, true, false);
SELECT assert_policy('status_public.user_achievements'::regclass, 'can_insert_user_achievements', 'insert', true, false, true);
SELECT assert_policy('status_public.user_achievements'::regclass, 'can_update_user_achievements', 'update', true, true, false);
SELECT assert_policy('status_public.user_achievements'::regclass, 'can_delete_user_achievements', 'delete', true, true, false);

SELECT assert_table_grant('status_public.user_achievements'::regclass, 'authenticated', 'INSERT');
SELECT assert_table_grant('status_public.user_achievements'::regclass, 'authenticated', 'SELECT');
SELECT assert_table_grant('status_public.user_achievements'::regclass, 'authenticated', 'UPDATE');
SELECT assert_table_grant('status_public.user_achievements'::regclass, 'authenticated', 'DELETE');

ROLLBACK;
