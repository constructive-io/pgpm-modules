-- Revert schemas/function_resolution/procedures/request_protection from pg

BEGIN;

DROP FUNCTION function_resolution.request_protection(uuid, uuid);

COMMIT;
