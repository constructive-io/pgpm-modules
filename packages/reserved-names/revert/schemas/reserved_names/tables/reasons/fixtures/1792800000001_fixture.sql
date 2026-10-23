-- Revert schemas/reserved_names/tables/reasons/fixtures/1792800000001_fixture from pg

BEGIN;

DELETE FROM reserved_names.reasons WHERE reason IN ('platform', 'brand', 'lookalike', 'abuse');

COMMIT;
