-- Verify schemas/inflection/procedures/singular  on pg

BEGIN;

SELECT assert_function('inflection.singular(text)'::regprocedure);

ROLLBACK;
