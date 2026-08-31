-- Revert schemas/app_scope/procedures/frame_owns from pg

BEGIN;

DROP FUNCTION app_scope.frame_owns(uuid, text, uuid, text, uuid, uuid);

COMMIT;
