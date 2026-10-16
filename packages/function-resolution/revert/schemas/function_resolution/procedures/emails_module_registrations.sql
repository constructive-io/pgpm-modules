-- Revert schemas/function_resolution/procedures/emails_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.emails_module_registrations(uuid);

COMMIT;
