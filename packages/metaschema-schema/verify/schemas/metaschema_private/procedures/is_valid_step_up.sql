-- Verify schemas/metaschema_private/procedures/is_valid_step_up on pg

BEGIN;

SELECT assert_function('metaschema_private.is_valid_step_up(jsonb)'::regprocedure);

SELECT assert_function('metaschema_private.is_valid_step_up_conditions(jsonb)'::regprocedure);

ROLLBACK;
