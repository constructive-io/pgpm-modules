-- Verify schemas/totp/procedures/random_base32  on pg

BEGIN;

SELECT assert_function('totp.random_base32(int4)'::regprocedure);

ROLLBACK;
