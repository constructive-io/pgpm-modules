-- Revert schemas/function_resolution/procedures/storage_file_ref_field from pg

BEGIN;

DROP FUNCTION function_resolution.storage_file_ref_field(text, text, text);

COMMIT;
