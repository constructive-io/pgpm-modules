-- Verify schemas/inflection/tables/inflection_rules/table on pg

BEGIN;

SELECT assert_table('inflection.inflection_rules'::regclass);

ROLLBACK;
