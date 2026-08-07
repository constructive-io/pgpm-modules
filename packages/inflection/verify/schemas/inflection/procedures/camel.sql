-- Verify schemas/inflection/procedures/camel  on pg

BEGIN;

SELECT assert_function('inflection.camel(text)'::regprocedure);

ROLLBACK;
