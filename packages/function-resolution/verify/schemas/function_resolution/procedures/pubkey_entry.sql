-- Verify schemas/function_resolution/procedures/pubkey_entry  on pg

BEGIN;

SELECT assert_function('function_resolution.pubkey_entry(uuid)'::regprocedure);

ROLLBACK;
