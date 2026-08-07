-- Verify schemas/inflection/procedures/dashed  on pg

BEGIN;

SELECT assert_function('inflection.dashed(text)'::regprocedure);

ROLLBACK;
