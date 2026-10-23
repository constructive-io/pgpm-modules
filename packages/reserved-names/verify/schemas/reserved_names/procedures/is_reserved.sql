-- Verify schemas/reserved_names/procedures/is_reserved on pg

BEGIN;

SELECT assert_function('reserved_names.is_reserved(text, text)'::regprocedure);

ROLLBACK;
