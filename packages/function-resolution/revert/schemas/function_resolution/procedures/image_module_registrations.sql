-- Revert schemas/function_resolution/procedures/image_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.image_module_registrations(uuid, text);

COMMIT;
