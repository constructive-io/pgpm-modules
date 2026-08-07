-- Deploy procedures/assert_view_rule to pg

BEGIN;

-- Asserts a rewrite rule is attached to this view and still fires on the event
-- it was created for.
--
--   SELECT assert_view_rule('my_schema.my_view'::regclass, '_insert', 'INSERT');

CREATE FUNCTION assert_view_rule (
    _view regclass,
    _rule name,
    _event text DEFAULT NULL
)
    RETURNS boolean
    AS $$
DECLARE
    found_event "char";
    wanted_event "char";
BEGIN
    SELECT
        ev_type INTO STRICT found_event
    FROM
        pg_catalog.pg_rewrite
    WHERE
        ev_class = _view
        AND rulename = _rule;

    IF _event IS NOT NULL THEN
        -- pg_rewrite.ev_type: 1 SELECT, 2 UPDATE, 3 INSERT, 4 DELETE.
        wanted_event := CASE lower(_event)
        WHEN 'select' THEN '1'
        WHEN 'update' THEN '2'
        WHEN 'insert' THEN '3'
        WHEN 'delete' THEN '4'
        END;

        IF wanted_event IS NULL THEN
            RAISE EXCEPTION 'Unsupported rule event --> %', _event;
        END IF;

        IF found_event <> wanted_event THEN
            RAISE EXCEPTION 'Rule % on % must fire on %', _rule, _view, upper(_event);
        END IF;
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
