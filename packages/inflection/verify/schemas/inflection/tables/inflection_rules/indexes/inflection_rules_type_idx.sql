-- Verify schemas/inflection/tables/inflection_rules/indexes/inflection_rules_type_idx  on pg

BEGIN;

SELECT assert_index('inflection.inflection_rules_type_idx'::regclass, 'inflection.inflection_rules'::regclass);

ROLLBACK;
