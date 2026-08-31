-- Revert schemas/function_resolution/procedures/install_route_bindings from pg

BEGIN;

DROP FUNCTION function_resolution.install_route_bindings(uuid, text, text, uuid, jsonb, uuid);

COMMIT;
