-- Verify schemas/secrets_schema/tables/secrets_table/table on pg

BEGIN;

SELECT assert_table('secrets_schema.secrets_table'::regclass);

ROLLBACK;
