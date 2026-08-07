-- Revert schemas/app_scope/procedures/projected_parent from pg

BEGIN;

DROP FUNCTION app_scope.projected_parent(uuid, text);

COMMIT;
