-- Revert schemas/function_resolution/procedures/api_hostnames from pg

BEGIN;

DROP FUNCTION function_resolution.api_hostnames(uuid);

COMMIT;
