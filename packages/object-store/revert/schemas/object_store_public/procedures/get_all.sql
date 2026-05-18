-- Revert schemas/object_store_public/procedures/get_all from pg

BEGIN;

DROP FUNCTION object_store_public.get_all;

COMMIT;
