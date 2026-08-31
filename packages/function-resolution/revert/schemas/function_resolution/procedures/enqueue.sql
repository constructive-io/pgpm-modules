-- Revert schemas/function_resolution/procedures/enqueue from pg

BEGIN;

DROP FUNCTION function_resolution.enqueue(text, json, text, uuid, uuid, text, text, text, timestamptz, int4, int4, uuid, text, bool, text, uuid, uuid, uuid, uuid);

COMMIT;
