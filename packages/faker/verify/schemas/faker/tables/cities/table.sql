-- Verify schemas/faker/tables/cities/table on pg

BEGIN;

SELECT assert_table('faker.cities'::regclass);

ROLLBACK;
