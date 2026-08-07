-- Deploy procedures/assert_table_security to pg

BEGIN;

-- Asserts row level security is enabled on a relation, and optionally that it
-- is forced for the table owner too.
--
--   SELECT assert_table_security('my_schema.users'::regclass);
--   SELECT assert_table_security('my_schema.users'::regclass, _forced => true);
--
-- Enabling RLS without a policy denies everything, and forcing it changes who
-- the policies apply to, so both are facts a caller depends on.

CREATE FUNCTION assert_table_security (
    _table regclass,
    _enabled boolean DEFAULT TRUE,
    _forced boolean DEFAULT NULL
)
    RETURNS boolean
    AS $$
DECLARE
    rel pg_catalog.pg_class%ROWTYPE;
BEGIN
    SELECT
        * INTO STRICT rel
    FROM
        pg_catalog.pg_class
    WHERE
        oid = _table;

    IF rel.relrowsecurity <> _enabled THEN
        RAISE EXCEPTION 'Row level security on % must be %', _table,
            CASE WHEN _enabled THEN 'enabled' ELSE 'disabled' END;
    END IF;

    IF _forced IS NOT NULL AND rel.relforcerowsecurity <> _forced THEN
        RAISE EXCEPTION 'Row level security on % must be % for the owner', _table,
            CASE WHEN _forced THEN 'forced' ELSE 'not forced' END;
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
