-- Revert schemas/reserved_names/tables/names/indexes/names_reason_idx from pg

BEGIN;

DROP INDEX reserved_names.names_reason_idx;

COMMIT;
