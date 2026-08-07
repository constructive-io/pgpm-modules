-- Verify schemas/inflection_db/procedures/get_table_name  on pg

BEGIN;

SELECT assert_function('inflection_db.get_table_name(text)'::regprocedure);
SELECT assert_function('inflection_db.get_table_name(text[])'::regprocedure);

ROLLBACK;
