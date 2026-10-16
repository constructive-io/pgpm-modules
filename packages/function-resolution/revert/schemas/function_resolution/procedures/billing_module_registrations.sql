-- Revert schemas/function_resolution/procedures/billing_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.billing_module_registrations(uuid);

COMMIT;
