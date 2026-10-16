-- Revert schemas/function_resolution/procedures/graph_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.graph_module_registrations(uuid, text);

COMMIT;
