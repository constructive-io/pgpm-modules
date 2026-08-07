-- Deploy procedures/assert_index to pg

BEGIN;

-- Asserts an index exists, covers the table it is supposed to cover, and is
-- still unique and valid.
--
--   SELECT assert_index('my_schema.users_email_key'::regclass,
--                       'my_schema.users'::regclass,
--                       _unique => true);
--
-- An invalid index (a failed CREATE INDEX CONCURRENTLY) exists in the catalog
-- but is ignored by the planner and enforces no uniqueness.

CREATE FUNCTION assert_index (
    _index regclass,
    _table regclass DEFAULT NULL,
    _unique boolean DEFAULT NULL
)
    RETURNS boolean
    AS $$
DECLARE
    ind pg_catalog.pg_index%ROWTYPE;
BEGIN
    SELECT
        * INTO STRICT ind
    FROM
        pg_catalog.pg_index
    WHERE
        indexrelid = _index;

    IF _table IS NOT NULL AND ind.indrelid <> _table THEN
        RAISE EXCEPTION 'Index % must index %, found %', _index, _table, ind.indrelid::regclass;
    END IF;

    IF _unique IS NOT NULL AND ind.indisunique <> _unique THEN
        RAISE EXCEPTION 'Index % must be %', _index,
            CASE WHEN _unique THEN 'UNIQUE' ELSE 'non-unique' END;
    END IF;

    IF NOT ind.indisvalid THEN
        RAISE EXCEPTION 'Index % must be valid', _index
            USING HINT = 'An invalid index is ignored by the planner and enforces nothing.';
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
