-- Revert schemas/function_resolution/procedures/cors_origins from pg

BEGIN;

DROP FUNCTION function_resolution.cors_origins(uuid, uuid);

COMMIT;
