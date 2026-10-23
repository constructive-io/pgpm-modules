-- Verify schemas/reserved_names/tables/names/table on pg

BEGIN;

SELECT assert_table('reserved_names.names'::regclass);

ROLLBACK;
