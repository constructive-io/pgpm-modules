-- Revert schemas/app_scope/procedures/actor_entity from pg

BEGIN;

DROP FUNCTION app_scope.actor_entity(uuid, uuid);

COMMIT;
