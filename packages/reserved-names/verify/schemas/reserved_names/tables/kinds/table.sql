-- Verify schemas/reserved_names/tables/kinds/table on pg

BEGIN;

SELECT assert_table('reserved_names.kinds'::regclass);

ROLLBACK;
