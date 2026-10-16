-- Revert schemas/function_resolution/procedures/file_ref_field_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.file_ref_field_registrations(uuid);

COMMIT;
