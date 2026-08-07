-- Verify schemas/totp/procedures/urlencode  on pg

BEGIN;

SELECT assert_function('totp.urlencode(text)'::regprocedure);

ROLLBACK;
