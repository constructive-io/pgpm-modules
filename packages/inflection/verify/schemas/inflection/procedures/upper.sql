-- Verify schemas/inflection/procedures/upper  on pg

BEGIN;

SELECT assert_function('inflection.upper(text)'::regprocedure);

ROLLBACK;
