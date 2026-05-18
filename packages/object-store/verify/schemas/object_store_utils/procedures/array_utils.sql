-- Verify schemas/object_store_utils/procedures/array_utils  on pg

BEGIN;

SELECT verify_function ('object_store_utils.zip_arrays');
SELECT verify_function ('object_store_utils.unzip_obj_to_ktree_and_kids');

ROLLBACK;
