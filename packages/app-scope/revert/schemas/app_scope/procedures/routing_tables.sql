-- Revert schemas/app_scope/procedures/routing_tables from pg

BEGIN;

DROP FUNCTION app_scope.routing_tables;

COMMIT;
