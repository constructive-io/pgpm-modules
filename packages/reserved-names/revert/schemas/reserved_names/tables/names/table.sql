-- Revert schemas/reserved_names/tables/names/table from pg

BEGIN;

DROP TABLE reserved_names.names;

COMMIT;
