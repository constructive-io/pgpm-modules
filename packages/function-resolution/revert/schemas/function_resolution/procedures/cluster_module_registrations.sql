-- Revert schemas/function_resolution/procedures/cluster_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.cluster_module_registrations(uuid, text);

COMMIT;
