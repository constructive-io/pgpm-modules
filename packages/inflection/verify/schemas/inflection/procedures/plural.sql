-- Verify schemas/inflection/procedures/plural  on pg

BEGIN;

SELECT assert_function('inflection.plural(text)'::regprocedure);

ROLLBACK;
