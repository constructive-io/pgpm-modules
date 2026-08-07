-- Verify schemas/inflection_db/procedures/get_check_constraint_name  on pg

BEGIN;

SELECT assert_function('inflection_db.get_check_constraint_name(text, text[])'::regprocedure);

ROLLBACK;
