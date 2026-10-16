-- Verify schemas/function_resolution/procedures/webauthn_entry  on pg

BEGIN;

SELECT assert_function('function_resolution.webauthn_entry(uuid)'::regprocedure);

ROLLBACK;
