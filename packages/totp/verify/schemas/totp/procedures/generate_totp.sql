-- Verify schemas/totp/procedures/generate_totp  on pg

BEGIN;

SELECT assert_function('totp.generate(text, int4, int4, timestamptz, text, text, int4)'::regprocedure);

ROLLBACK;
