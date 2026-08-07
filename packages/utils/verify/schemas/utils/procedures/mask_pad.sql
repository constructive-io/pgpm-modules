-- Verify schemas/utils/procedures/mask_pad  on pg

BEGIN;

SELECT assert_function('utils.mask_pad(text, int4, text)'::regprocedure);

ROLLBACK;
