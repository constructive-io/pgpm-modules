-- Verify schemas/status_public/tables/levels/table on pg

BEGIN;

SELECT assert_table('status_public.levels'::regclass);

ROLLBACK;
