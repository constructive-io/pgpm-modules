-- Verify schemas/app_scope/procedures/actor_entity  on pg

BEGIN;

SELECT assert_function('app_scope.actor_entity(uuid, uuid)'::regprocedure);

ROLLBACK;
