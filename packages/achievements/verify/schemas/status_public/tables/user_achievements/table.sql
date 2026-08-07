-- Verify schemas/status_public/tables/user_achievements/table on pg

BEGIN;

SELECT assert_table('status_public.user_achievements'::regclass);

ROLLBACK;
