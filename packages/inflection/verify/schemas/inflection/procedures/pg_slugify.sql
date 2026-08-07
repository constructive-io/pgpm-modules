-- Verify schemas/inflection/procedures/pg_slugify  on pg

BEGIN;

SELECT assert_function('inflection.pg_slugify(text, bool)'::regprocedure);
SELECT assert_function('inflection.pg_slugify(text)'::regprocedure);

ROLLBACK;
