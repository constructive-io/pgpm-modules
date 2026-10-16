-- Revert schemas/function_resolution/procedures/oauth_requests_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.oauth_requests_module_registrations(uuid);

COMMIT;
