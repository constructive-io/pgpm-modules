-- Revert schemas/function_resolution/procedures/tenant_auth_entry from pg

BEGIN;

DROP FUNCTION function_resolution.tenant_auth_entry(uuid);

COMMIT;
