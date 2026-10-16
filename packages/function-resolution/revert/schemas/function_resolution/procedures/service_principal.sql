-- Revert schemas/function_resolution/procedures/service_principal from pg

BEGIN;

DROP FUNCTION function_resolution.service_principal(text);

COMMIT;
