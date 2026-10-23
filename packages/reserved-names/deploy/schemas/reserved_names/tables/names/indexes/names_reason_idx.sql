-- Deploy schemas/reserved_names/tables/names/indexes/names_reason_idx to pg

-- requires: schemas/reserved_names/schema
-- requires: schemas/reserved_names/tables/names/table

BEGIN;

CREATE INDEX names_reason_idx ON reserved_names.names (reason);

COMMIT;
