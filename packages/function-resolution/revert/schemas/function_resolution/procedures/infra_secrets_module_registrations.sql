-- Revert schemas/function_resolution/procedures/infra_secrets_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.infra_secrets_module_registrations(uuid, text);

COMMIT;
