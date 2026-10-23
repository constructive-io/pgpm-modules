-- Revert schemas/reserved_names/tables/reasons/table from pg

BEGIN;

DROP TABLE reserved_names.reasons;

COMMIT;
