-- Revert schemas/function_resolution/procedures/database_standing from pg

BEGIN;

DROP FUNCTION function_resolution.database_standing(uuid);

COMMIT;
