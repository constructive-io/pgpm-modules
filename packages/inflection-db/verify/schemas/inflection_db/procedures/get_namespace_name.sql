-- Verify schemas/inflection_db/procedures/get_namespace_name on pg

BEGIN;

SELECT assert_function('inflection_db.get_namespace_name(text[])'::regprocedure);

ROLLBACK;
