-- Revert schemas/function_resolution/procedures/routing_planes from pg

BEGIN;

DROP FUNCTION function_resolution.routing_planes();

COMMIT;
