-- Verify schemas/object_store_public/procedures/set_data_at_path  on pg

BEGIN;

SELECT verify_function ('object_store_public.set_data_at_path');

ROLLBACK;
