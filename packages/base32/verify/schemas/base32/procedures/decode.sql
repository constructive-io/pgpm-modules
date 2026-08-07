-- Verify schemas/base32/procedures/decode  on pg

BEGIN;

SELECT assert_function('base32.decode(text)'::regprocedure);

ROLLBACK;
