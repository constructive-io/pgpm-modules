-- Deploy procedures/assert_policy to pg

-- requires: procedures/assert_policy_command_label

BEGIN;

-- Asserts an RLS policy is attached to this table and still applies to the same
-- command, with the same permissiveness and the same clauses.
--
--   SELECT assert_policy('my_schema.docs'::regclass, 'can_select', 'SELECT',
--                        _permissive => true, _has_qual => true);
--
-- Each expectation is optional, because an ALTER POLICY action can only speak
-- for the clause it altered: the command and the permissiveness a policy was
-- created with cannot be changed by ALTER POLICY at all.

CREATE FUNCTION assert_policy (
    _table regclass,
    _policy name,
    _command text DEFAULT NULL,
    _permissive boolean DEFAULT NULL,
    _has_qual boolean DEFAULT NULL,
    _has_with_check boolean DEFAULT NULL
)
    RETURNS boolean
    AS $$
DECLARE
    pol pg_catalog.pg_policy%ROWTYPE;
    wanted_cmd "char";
BEGIN
    SELECT
        * INTO STRICT pol
    FROM
        pg_catalog.pg_policy
    WHERE
        polrelid = _table
        AND polname = _policy;

    IF _command IS NOT NULL THEN
        -- pg_policy.polcmd: '*' ALL, 'r' SELECT, 'a' INSERT, 'w' UPDATE, 'd' DELETE.
        wanted_cmd := CASE lower(_command)
        WHEN 'all' THEN '*'
        WHEN 'select' THEN 'r'
        WHEN 'insert' THEN 'a'
        WHEN 'update' THEN 'w'
        WHEN 'delete' THEN 'd'
        END;

        IF wanted_cmd IS NULL THEN
            RAISE EXCEPTION 'Unsupported policy command --> %', _command;
        END IF;

        IF pol.polcmd <> wanted_cmd THEN
            RAISE EXCEPTION 'Policy % on % must apply to %, found %', _policy, _table,
                upper(_command), assert_policy_command_label (pol.polcmd);
        END IF;
    END IF;

    IF _permissive IS NOT NULL AND pol.polpermissive <> _permissive THEN
        RAISE EXCEPTION 'Policy % on % must be %', _policy, _table,
            CASE WHEN _permissive THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END
            USING HINT = 'A restrictive policy turned permissive widens access instead of narrowing it.';
    END IF;

    IF _has_qual IS NOT NULL AND (pol.polqual IS NOT NULL) <> _has_qual THEN
        RAISE EXCEPTION 'Policy % on % must % a USING clause', _policy, _table,
            CASE WHEN _has_qual THEN 'carry' ELSE 'not carry' END;
    END IF;

    IF _has_with_check IS NOT NULL AND (pol.polwithcheck IS NOT NULL) <> _has_with_check THEN
        RAISE EXCEPTION 'Policy % on % must % a WITH CHECK clause', _policy, _table,
            CASE WHEN _has_with_check THEN 'carry' ELSE 'not carry' END;
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
