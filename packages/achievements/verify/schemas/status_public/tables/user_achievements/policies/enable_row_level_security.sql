-- Verify schemas/status_public/tables/user_achievements/policies/enable_row_level_security  on pg

BEGIN;

SELECT assert_table_security('status_public.user_achievements'::regclass);

ROLLBACK;
