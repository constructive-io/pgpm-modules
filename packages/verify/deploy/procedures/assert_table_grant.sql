-- Deploy procedures/assert_table_grant to pg

BEGIN;

-- Asserts a role does (or does not) hold a privilege on a relation.
--
--   SELECT assert_table_grant('my_schema.users'::regclass, 'authenticated', 'SELECT');
--   SELECT assert_table_grant('my_schema.users'::regclass, 'authenticated', 'INSERT',
--                             ARRAY['display_name', 'username']);
--
-- Columns matter: GRANT INSERT (display_name) is a column-scoped privilege, and
-- the role holds no table-wide INSERT at all.  A check that reads
-- information_schema.role_table_grants -- which lists table-wide grants only --
-- reports that as missing, so every column-scoped grant failed its verify.
-- has_column_privilege answers the question actually being asked, and both
-- forms resolve inherited and PUBLIC grants the way a client would experience
-- them.

CREATE FUNCTION assert_table_grant (
    _relation regclass,
    _role name,
    _privilege text,
    _columns text[] DEFAULT NULL,
    _granted boolean DEFAULT TRUE
)
    RETURNS boolean
    AS $$
DECLARE
    col text;
    offending text[] = ARRAY[]::text[];
    held boolean;
BEGIN
    IF _columns IS NULL OR cardinality(_columns) = 0 THEN
        held = pg_catalog.has_table_privilege(_role, _relation, _privilege);

        IF held <> _granted THEN
            RAISE EXCEPTION 'Role % must % % on %', _role,
                CASE WHEN _granted THEN 'hold' ELSE 'not hold' END,
                _privilege, _relation;
        END IF;

        RETURN TRUE;
    END IF;

    FOREACH col IN ARRAY _columns LOOP
        IF pg_catalog.has_column_privilege(_role, _relation, col, _privilege) <> _granted THEN
            offending = offending || col;
        END IF;
    END LOOP;

    IF cardinality(offending) > 0 THEN
        RAISE EXCEPTION 'Role % must % % on %.(%)', _role,
            CASE WHEN _granted THEN 'hold' ELSE 'not hold' END,
            _privilege, _relation, array_to_string(offending, ', ');
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
