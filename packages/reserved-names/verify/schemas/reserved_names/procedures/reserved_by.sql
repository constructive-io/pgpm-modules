-- Verify schemas/reserved_names/procedures/reserved_by on pg

BEGIN;

SELECT assert_function('reserved_names.reserved_by(text, text)'::regprocedure);

ROLLBACK;
