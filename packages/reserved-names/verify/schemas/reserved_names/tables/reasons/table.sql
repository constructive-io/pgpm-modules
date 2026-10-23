-- Verify schemas/reserved_names/tables/reasons/table on pg

BEGIN;

SELECT assert_table('reserved_names.reasons'::regclass);

ROLLBACK;
