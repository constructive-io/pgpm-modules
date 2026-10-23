-- Verify schemas/reserved_names/tables/names/fixtures/1792800000002_fixture on pg

BEGIN;

SELECT 1/count(*) FROM reserved_names.names WHERE kind = 'subdomain' AND name = 'login';

ROLLBACK;
