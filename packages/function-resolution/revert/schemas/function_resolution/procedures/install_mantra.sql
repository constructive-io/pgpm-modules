-- Revert schemas/function_resolution/procedures/install_mantra from pg

BEGIN;

DROP FUNCTION function_resolution.install_mantra(uuid, regclass, uuid, jsonb, uuid);

COMMIT;
