-- Verify schemas/base32/procedures/encode  on pg

BEGIN;

SELECT assert_function('base32.encode(text)'::regprocedure);

ROLLBACK;
