-- Deploy procedures/assert_type to pg

BEGIN;

-- Asserts a type exists under exactly this name and is the kind of type it is
-- supposed to be.
--
--   SELECT assert_type('public.origin'::regtype);
--   SELECT assert_type('public.rgb'::regtype, _kind => 'e');
--
-- The identity is a regtype, so a type that was renamed or dropped raises at
-- resolution time rather than being reported as a missing row.

CREATE FUNCTION assert_type (
    _type regtype,
    _kind "char" DEFAULT NULL
)
    RETURNS boolean
    AS $$
DECLARE
    typ pg_catalog.pg_type%ROWTYPE;
BEGIN
    SELECT
        * INTO STRICT typ
    FROM
        pg_catalog.pg_type
    WHERE
        oid = _type;

    IF typ.typtype = 'd' THEN
        RAISE EXCEPTION '% is a domain', _type
            USING HINT = 'Use assert_domain for a domain.';
    END IF;

    IF _kind IS NOT NULL AND typ.typtype <> _kind THEN
        RAISE EXCEPTION 'Type % must be typtype %, found %', _type, _kind, typ.typtype;
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
