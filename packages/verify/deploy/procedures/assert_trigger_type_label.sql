-- Deploy procedures/assert_trigger_type_label to pg

BEGIN;

-- Spells a pg_trigger.tgtype bitmask the way CREATE TRIGGER spells it, so an
-- assertion failure reads 'BEFORE INSERT OR UPDATE FOR EACH ROW' rather than
-- comparing two integers.

CREATE FUNCTION assert_trigger_type_label (_tgtype int)
    RETURNS text
    AS $$
DECLARE
    events text[] = ARRAY[]::text[];
BEGIN
    IF (_tgtype & 4) = 4 THEN
        events := array_append(events, 'INSERT');
    END IF;

    IF (_tgtype & 8) = 8 THEN
        events := array_append(events, 'DELETE');
    END IF;

    IF (_tgtype & 16) = 16 THEN
        events := array_append(events, 'UPDATE');
    END IF;

    IF (_tgtype & 32) = 32 THEN
        events := array_append(events, 'TRUNCATE');
    END IF;

    RETURN format('%s %s FOR EACH %s',
        CASE
        WHEN (_tgtype & 64) = 64 THEN 'INSTEAD OF'
        WHEN (_tgtype & 2) = 2 THEN 'BEFORE'
        ELSE 'AFTER'
        END,
        array_to_string(events, ' OR '),
        CASE WHEN (_tgtype & 1) = 1 THEN 'ROW' ELSE 'STATEMENT' END);
END;
$$
LANGUAGE 'plpgsql'
IMMUTABLE;

COMMIT;
