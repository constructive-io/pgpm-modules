-- Revert schemas/function_resolution/procedures/billing_provider_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.billing_provider_module_registrations(uuid);

COMMIT;
