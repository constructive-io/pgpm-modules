-- Verify schemas/inflection/procedures/slugify_trigger  on pg

BEGIN;

SELECT assert_function('inflection.slugify_trigger()'::regprocedure);

ROLLBACK;
