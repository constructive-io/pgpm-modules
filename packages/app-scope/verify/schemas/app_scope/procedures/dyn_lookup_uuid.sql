-- Verify schemas/app_scope/procedures/dyn_lookup_uuid  on pg

BEGIN;

SELECT assert_function('app_scope.dyn_lookup_uuid(text, text, text, uuid)'::regprocedure);

ROLLBACK;
