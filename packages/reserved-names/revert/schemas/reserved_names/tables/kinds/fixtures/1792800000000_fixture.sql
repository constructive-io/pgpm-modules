-- Revert schemas/reserved_names/tables/kinds/fixtures/1792800000000_fixture from pg

BEGIN;

DELETE FROM reserved_names.kinds WHERE kind IN ('subdomain', 'username', 'domain', 'slug');

COMMIT;
