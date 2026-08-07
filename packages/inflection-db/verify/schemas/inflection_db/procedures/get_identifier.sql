-- Verify schemas/inflection_db/procedures/get_identifier  on pg

BEGIN;

SELECT assert_function('inflection_db.get_identifier(text)'::regprocedure);

ROLLBACK;
