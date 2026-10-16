-- Revert schemas/function_resolution/procedures/domain_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.domain_module_registrations(uuid, text);

COMMIT;
