-- Verify schemas/inflection/procedures/no_consecutive_caps  on pg

BEGIN;

SELECT assert_function('inflection.no_consecutive_caps(text)'::regprocedure);

ROLLBACK;
