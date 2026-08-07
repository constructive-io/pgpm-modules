-- Deploy procedures/assert_function_grant to pg

BEGIN;

-- Asserts a role does (or does not) hold a privilege on a function.
--
--   SELECT assert_function_grant('app_jobs.add_job(text)'::regprocedure, 'authenticated');
--
-- The function is named as a regprocedure, so a signature that no longer exists
-- raises here instead of being reported as an absent privilege.

CREATE FUNCTION assert_function_grant (
    _function regprocedure,
    _role name,
    _privilege text DEFAULT 'EXECUTE',
    _granted boolean DEFAULT TRUE
)
    RETURNS boolean
    AS $$
BEGIN
    IF pg_catalog.has_function_privilege(_role, _function, _privilege) <> _granted THEN
        RAISE EXCEPTION 'Role % must % % on %', _role,
            CASE WHEN _granted THEN 'hold' ELSE 'not hold' END,
            _privilege, _function;
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
