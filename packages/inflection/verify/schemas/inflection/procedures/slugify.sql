-- Verify schemas/inflection/procedures/slugify  on pg

BEGIN;

SELECT assert_function('inflection.slugify(text, bool)'::regprocedure);
SELECT assert_function('inflection.slugify(text)'::regprocedure);

ROLLBACK;
