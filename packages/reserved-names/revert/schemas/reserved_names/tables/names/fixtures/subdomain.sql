-- Revert schemas/reserved_names/tables/names/fixtures/subdomain from pg

BEGIN;

DELETE FROM reserved_names.names WHERE kind = 'subdomain';

COMMIT;
