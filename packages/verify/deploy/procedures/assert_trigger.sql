-- Deploy procedures/assert_trigger to pg

-- requires: procedures/assert_trigger_type_label

BEGIN;

-- Asserts a trigger is attached to this table, calls the function it was
-- created with, fires with the same timing/events/level, and is enabled.
--
--   SELECT assert_trigger('my_schema.users'::regclass, 'stamps',
--                         'stamps.timestamps'::regproc, 23);
--
-- A trigger name is unique per table, not per schema, so the table is part of
-- the identity rather than context. _tgtype is the pg_trigger bitmask:
-- BEFORE 2, INSTEAD OF 64, AFTER 0; INSERT 4, DELETE 8, UPDATE 16,
-- TRUNCATE 32; FOR EACH ROW 1.

CREATE FUNCTION assert_trigger (
    _table regclass,
    _trigger name,
    _function regproc DEFAULT NULL,
    _tgtype int DEFAULT NULL,
    _enabled boolean DEFAULT true
)
    RETURNS boolean
    AS $$
DECLARE
    trg pg_catalog.pg_trigger%ROWTYPE;
BEGIN
    SELECT
        * INTO STRICT trg
    FROM
        pg_catalog.pg_trigger
    WHERE
        tgrelid = _table
        AND tgname = _trigger;

    IF _function IS NOT NULL AND trg.tgfoid <> _function THEN
        RAISE EXCEPTION 'Trigger % on % must call %, found %', _trigger, _table, _function, trg.tgfoid::regproc;
    END IF;

    IF _tgtype IS NOT NULL AND trg.tgtype <> _tgtype THEN
        RAISE EXCEPTION 'Trigger % on % must be %, found %', _trigger, _table,
            assert_trigger_type_label (_tgtype), assert_trigger_type_label (trg.tgtype);
    END IF;

    IF _enabled IS NOT NULL AND (trg.tgenabled <> 'D') <> _enabled THEN
        RAISE EXCEPTION 'Trigger % on % must be %', _trigger, _table,
            CASE WHEN _enabled THEN 'enabled' ELSE 'disabled' END
            USING HINT = 'ALTER TABLE ... DISABLE TRIGGER leaves the catalog row in place.';
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
