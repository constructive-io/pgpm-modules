-- Verify schemas/inflection/procedures/should_skip_uncountable  on pg

BEGIN;

SELECT assert_function('inflection.should_skip_uncountable(text)'::regprocedure);

ROLLBACK;
