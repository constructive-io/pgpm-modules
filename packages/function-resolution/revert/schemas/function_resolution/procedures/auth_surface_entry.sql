-- Revert schemas/function_resolution/procedures/auth_surface_entry from pg

BEGIN;

DROP FUNCTION function_resolution.auth_surface_entry(uuid);

COMMIT;
