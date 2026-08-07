-- Verify schemas/ctx/procedures/security_definer  on pg

BEGIN;

SELECT assert_function('ctx.security_definer()'::regprocedure, 'text'::regtype);
SELECT assert_function('ctx.is_security_definer()'::regprocedure, 'boolean'::regtype);

ROLLBACK;
