-- Revert schemas/object_store_public/tables/object/triggers/generate_id_hash from pg

BEGIN;

DROP TRIGGER generate_id_hash ON object_store_public.object;
DROP FUNCTION object_store_private.tg_generate_id_hash; 

COMMIT;
