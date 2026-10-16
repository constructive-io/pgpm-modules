-- Verify schemas/function_resolution/procedures/storage_file_ref_field  on pg

BEGIN;

SELECT assert_function('function_resolution.storage_file_ref_field(text, text, text)'::regprocedure);

ROLLBACK;
