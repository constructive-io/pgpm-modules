-- Verify schemas/inflection/procedures/pascal  on pg

BEGIN;

SELECT assert_function('inflection.pascal(text)'::regprocedure);

ROLLBACK;
