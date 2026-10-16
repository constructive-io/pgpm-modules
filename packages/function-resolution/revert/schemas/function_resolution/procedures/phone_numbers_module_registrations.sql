-- Revert schemas/function_resolution/procedures/phone_numbers_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.phone_numbers_module_registrations(uuid);

COMMIT;
