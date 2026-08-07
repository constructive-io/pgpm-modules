-- Deploy procedures/assert_policy_command_label to pg

BEGIN;

-- Spells a pg_policy.polcmd letter for an assertion message.

CREATE FUNCTION assert_policy_command_label (_polcmd "char")
    RETURNS text
    AS $$
    SELECT
        CASE _polcmd
        WHEN '*' THEN 'ALL'
        WHEN 'r' THEN 'SELECT'
        WHEN 'a' THEN 'INSERT'
        WHEN 'w' THEN 'UPDATE'
        WHEN 'd' THEN 'DELETE'
        ELSE format('command %L', _polcmd)
        END;
$$
LANGUAGE 'sql'
IMMUTABLE;

COMMIT;
