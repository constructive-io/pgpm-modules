-- Verify schemas/reserved_names/tables/kinds/fixtures/1792800000000_fixture on pg

BEGIN;

SELECT 1/count(*) FROM reserved_names.kinds WHERE kind = 'subdomain';

ROLLBACK;
