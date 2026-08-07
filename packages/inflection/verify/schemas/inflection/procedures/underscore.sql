-- Verify schemas/inflection/procedures/underscore  on pg

BEGIN;

SELECT assert_function('inflection.underscore(text)'::regprocedure);
SELECT assert_function('inflection.underscore(text[])'::regprocedure);
SELECT assert_function('inflection.underscore(text)'::regprocedure);
SELECT assert_function('inflection.underscore(text[])'::regprocedure);

ROLLBACK;
