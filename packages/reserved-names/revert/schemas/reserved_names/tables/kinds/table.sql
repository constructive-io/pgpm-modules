-- Revert schemas/reserved_names/tables/kinds/table from pg

BEGIN;

DROP TABLE reserved_names.kinds;

COMMIT;
