-- Revert schemas/object_store_utils/procedures/array_utils from pg

BEGIN;

DROP FUNCTION object_store_utils.zip_arrays;
DROP FUNCTION object_store_utils.unzip_obj_to_ktree_and_kids;

COMMIT;
