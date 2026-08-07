-- Verify schemas/inflection_db/procedures/get_unique_index_name  on pg

BEGIN;

SELECT assert_function('inflection_db.get_unique_index_name(text, text[])'::regprocedure);

ROLLBACK;
