-- Revert schemas/function_resolution/procedures/webhook_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.webhook_module_registrations(uuid, text);

COMMIT;
