-- Deploy procedures/assert_domain to pg

BEGIN;

-- Asserts a domain exists under exactly this name, is built on the base type it
-- is supposed to be, and still carries its constraints.
--
--   SELECT assert_domain('public.email'::regtype);
--   SELECT assert_domain('public.email'::regtype, 'text'::regtype, _not_null => true);
--   SELECT assert_domain('public.email'::regtype, _constraints => 1);
--
-- A domain whose CHECK constraint was dropped still exists, so the constraint
-- count is the part that catches a domain that has stopped validating anything.

CREATE FUNCTION assert_domain (
    _domain regtype,
    _base regtype DEFAULT NULL,
    _not_null boolean DEFAULT NULL,
    _constraints int DEFAULT NULL
)
    RETURNS boolean
    AS $$
DECLARE
    typ pg_catalog.pg_type%ROWTYPE;
    found_constraints int;
BEGIN
    SELECT
        * INTO STRICT typ
    FROM
        pg_catalog.pg_type
    WHERE
        oid = _domain;

    IF typ.typtype <> 'd' THEN
        RAISE EXCEPTION '% must be a domain', _domain;
    END IF;

    IF _base IS NOT NULL AND typ.typbasetype <> _base THEN
        RAISE EXCEPTION 'Domain % must be built on %, found %', _domain, _base,
            typ.typbasetype::regtype;
    END IF;

    IF _not_null IS NOT NULL AND typ.typnotnull <> _not_null THEN
        RAISE EXCEPTION 'Domain % must be %', _domain,
            CASE WHEN _not_null THEN 'NOT NULL' ELSE 'nullable' END;
    END IF;

    IF _constraints IS NOT NULL THEN
        SELECT
            count(*) INTO found_constraints
        FROM
            pg_catalog.pg_constraint
        WHERE
            contypid = _domain;

        IF found_constraints <> _constraints THEN
            RAISE EXCEPTION 'Domain % must carry % constraint(s), found %', _domain,
                _constraints, found_constraints;
        END IF;
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
