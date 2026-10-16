-- Revert schemas/function_resolution/procedures/agent_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.agent_module_registrations(uuid);

COMMIT;
