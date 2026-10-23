-- Verify schemas/reserved_names/tables/reasons/fixtures/1792800000001_fixture on pg

BEGIN;

SELECT 1/count(*) FROM reserved_names.reasons WHERE reason = 'platform';

ROLLBACK;
