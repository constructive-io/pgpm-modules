-- Revert schemas/function_resolution/procedures/events_entry from pg

BEGIN;

DROP FUNCTION function_resolution.events_entry(uuid);

COMMIT;
