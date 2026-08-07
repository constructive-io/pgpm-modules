-- Deploy procedures/assert_table to pg

-- requires: procedures/assert_relkind_label

BEGIN;

-- Asserts a relation exists under exactly this schema-qualified name and is the
-- kind of table it is supposed to be.
--
--   SELECT assert_table('my_schema.my_table'::regclass);
--   SELECT assert_table('my_schema.events'::regclass, _partitioned => true);
--
-- The regclass cast resolves the name, so a table replaced by a view of the
-- same name fails here rather than passing a name-only check.

CREATE FUNCTION assert_table (
    _table regclass,
    _partitioned boolean DEFAULT false,
    _is_partition boolean DEFAULT NULL
)
    RETURNS boolean
    AS $$
DECLARE
    rel pg_catalog.pg_class%ROWTYPE;
    -- plpgsql reads an IF condition up to the first THEN, so a CASE cannot be
    -- inlined there.
    wanted_kind "char" = CASE WHEN _partitioned THEN 'p' ELSE 'r' END;
BEGIN
    SELECT
        * INTO STRICT rel
    FROM
        pg_catalog.pg_class
    WHERE
        oid = _table;

    IF rel.relkind <> wanted_kind THEN
        RAISE EXCEPTION 'Relation % must be %, found %', _table,
            CASE WHEN _partitioned THEN 'a partitioned table' ELSE 'an ordinary table' END,
            assert_relkind_label (rel.relkind);
    END IF;

    IF _is_partition IS NOT NULL AND rel.relispartition <> _is_partition THEN
        RAISE EXCEPTION 'Table % must % a partition of another table', _table,
            CASE WHEN _is_partition THEN 'be' ELSE 'not be' END;
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
