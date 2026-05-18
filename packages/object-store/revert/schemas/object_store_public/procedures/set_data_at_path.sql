-- Revert schemas/object_store_public/procedures/set_data_at_path from pg

BEGIN;

DROP FUNCTION object_store_public.set_data_at_path;

COMMIT;
