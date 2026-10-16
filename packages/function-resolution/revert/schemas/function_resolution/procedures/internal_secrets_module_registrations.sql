-- Revert schemas/function_resolution/procedures/internal_secrets_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.internal_secrets_module_registrations(uuid);

COMMIT;
