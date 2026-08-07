-- Verify schemas/inflection/procedures/lower  on pg

BEGIN;

SELECT assert_function('inflection.lower(text)'::regprocedure);

ROLLBACK;
