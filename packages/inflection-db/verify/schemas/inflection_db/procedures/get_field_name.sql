-- Verify schemas/inflection_db/procedures/get_field_name  on pg

BEGIN;

SELECT assert_function('inflection_db.get_field_name(text)'::regprocedure);
SELECT assert_function('inflection_db.get_field_name(text[])'::regprocedure);

ROLLBACK;
