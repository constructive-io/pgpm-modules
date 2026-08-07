-- Deploy procedures/assert_relkind_label to pg

BEGIN;

-- Spells a pg_class.relkind for an assertion message, so a failure says what
-- the relation actually is instead of printing a bare letter.

CREATE FUNCTION assert_relkind_label (_relkind "char")
    RETURNS text
    AS $$
    SELECT
        CASE _relkind
        WHEN 'r' THEN 'an ordinary table'
        WHEN 'p' THEN 'a partitioned table'
        WHEN 'v' THEN 'a view'
        WHEN 'm' THEN 'a materialized view'
        WHEN 'i' THEN 'an index'
        WHEN 'I' THEN 'a partitioned index'
        WHEN 'S' THEN 'a sequence'
        WHEN 'f' THEN 'a foreign table'
        WHEN 'c' THEN 'a composite type'
        WHEN 't' THEN 'a TOAST table'
        ELSE format('a relation of kind %L', _relkind)
        END;
$$
LANGUAGE 'sql'
IMMUTABLE;

COMMIT;
