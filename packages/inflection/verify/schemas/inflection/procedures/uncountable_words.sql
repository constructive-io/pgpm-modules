-- Verify schemas/inflection/procedures/uncountable_words  on pg

BEGIN;

SELECT assert_function('inflection.uncountable_words()'::regprocedure);

ROLLBACK;
