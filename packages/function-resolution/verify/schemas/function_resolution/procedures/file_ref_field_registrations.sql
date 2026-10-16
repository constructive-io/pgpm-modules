-- Verify schemas/function_resolution/procedures/file_ref_field_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.file_ref_field_registrations(uuid)'::regprocedure);

ROLLBACK;
