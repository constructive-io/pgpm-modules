-- Verify schemas/inflection/procedures/no_single_underscores  on pg

BEGIN;

SELECT assert_function('inflection.no_single_underscores(text)'::regprocedure);

ROLLBACK;
