-- Verify schemas/status_public/tables/user_steps/table on pg

BEGIN;

SELECT assert_table('status_public.user_steps'::regclass);

ROLLBACK;
