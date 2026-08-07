-- Deploy procedures/assert_function to pg

BEGIN;

-- Asserts a function exists with exactly this signature, and that the parts of
-- its definition a caller depends on have not drifted.
--
-- The function is named as a regprocedure so the signature is resolved by
-- Postgres rather than matched by name: a missing overload raises here, where a
-- name-only check happily passes on a different one.
--
--   SELECT assert_function('my_schema.my_fn(uuid, text)'::regprocedure, 'boolean'::regtype);
--
-- Every expectation is optional; NULL means the caller does not know it.

CREATE FUNCTION assert_function (
    _function regprocedure,
    _return_type regtype DEFAULT NULL,
    _returns_set boolean DEFAULT NULL,
    _security_definer boolean DEFAULT NULL,
    _volatility text DEFAULT NULL
)
    RETURNS boolean
    AS $$
DECLARE
    proc pg_catalog.pg_proc%ROWTYPE;
    found_volatility text;
BEGIN
    SELECT
        * INTO STRICT proc
    FROM
        pg_catalog.pg_proc
    WHERE
        oid = _function;

    IF _return_type IS NOT NULL AND proc.prorettype <> _return_type THEN
        RAISE EXCEPTION 'Function % must return %, found %', _function, _return_type, proc.prorettype::regtype
            USING HINT = 'The return type changed; callers and views built on it will break.';
    END IF;

    IF _returns_set IS NOT NULL AND proc.proretset <> _returns_set THEN
        RAISE EXCEPTION 'Function % must return %', _function,
            CASE WHEN _returns_set THEN 'a set' ELSE 'a single row' END;
    END IF;

    IF _security_definer IS NOT NULL AND proc.prosecdef <> _security_definer THEN
        RAISE EXCEPTION 'Function % must be SECURITY %', _function,
            CASE WHEN _security_definer THEN 'DEFINER' ELSE 'INVOKER' END
            USING HINT = 'An unintended SECURITY DEFINER runs as the owner and bypasses RLS.';
    END IF;

    IF _volatility IS NOT NULL THEN
        found_volatility := CASE proc.provolatile
        WHEN 'i' THEN 'IMMUTABLE'
        WHEN 's' THEN 'STABLE'
        ELSE 'VOLATILE'
        END;

        IF found_volatility <> upper(_volatility) THEN
            RAISE EXCEPTION 'Function % must be %, found %', _function, upper(_volatility), found_volatility;
        END IF;
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
