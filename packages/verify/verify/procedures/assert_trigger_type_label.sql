-- Verify procedures/assert_trigger_type_label on pg

BEGIN;

SELECT assert_function('assert_trigger_type_label(int4)'::regprocedure);

ROLLBACK;
