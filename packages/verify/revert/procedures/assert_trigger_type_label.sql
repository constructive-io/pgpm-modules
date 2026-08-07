-- Revert procedures/assert_trigger_type_label from pg

BEGIN;

DROP FUNCTION assert_trigger_type_label(int4);

COMMIT;
