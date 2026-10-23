-- Verify schemas/reserved_names/tables/names/indexes/names_reason_idx on pg

BEGIN;

SELECT assert_index('reserved_names.names_reason_idx'::regclass, 'reserved_names.names'::regclass);

ROLLBACK;
