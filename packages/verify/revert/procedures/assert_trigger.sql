-- Revert procedures/assert_trigger from pg

BEGIN;

DROP FUNCTION assert_trigger(regclass, name, regproc, int4, bool);

COMMIT;
