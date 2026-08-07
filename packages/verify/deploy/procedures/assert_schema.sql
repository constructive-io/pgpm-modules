-- Deploy procedures/assert_schema to pg

BEGIN;

-- Asserts a schema exists.
--
--   SELECT assert_schema('my_schema'::regnamespace);
--
-- The regnamespace cast is the assertion: a missing schema fails while
-- resolving the argument, so the name is a reference the parser owns rather
-- than opaque text a name-only check compares. The body catches the schema
-- being dropped between planning and execution.

CREATE FUNCTION assert_schema (
    _schema regnamespace
)
    RETURNS boolean
    AS $$
BEGIN
    PERFORM
        1
    FROM
        pg_catalog.pg_namespace
    WHERE
        oid = _schema;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Nonexistent schema --> %', _schema;
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
