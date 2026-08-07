-- Verify schemas/faker/tables/dictionary/table on pg

BEGIN;

SELECT assert_table('faker.dictionary'::regclass);

ROLLBACK;
