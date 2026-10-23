-- Revert schemas/reserved_names/tables/names/fixtures/1792800000002_fixture from pg

BEGIN;

DELETE FROM reserved_names.names WHERE kind = 'subdomain';

COMMIT;
