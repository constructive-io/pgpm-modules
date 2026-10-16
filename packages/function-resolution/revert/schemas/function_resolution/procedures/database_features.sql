-- Revert schemas/function_resolution/procedures/database_features from pg

BEGIN;

DROP FUNCTION function_resolution.database_features(uuid, uuid);

COMMIT;
