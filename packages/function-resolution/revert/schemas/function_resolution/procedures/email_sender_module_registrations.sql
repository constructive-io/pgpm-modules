-- Revert schemas/function_resolution/procedures/email_sender_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.email_sender_module_registrations(uuid);

COMMIT;
