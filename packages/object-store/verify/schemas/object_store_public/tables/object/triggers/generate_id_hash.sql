-- Verify schemas/object_store_public/tables/object/triggers/generate_id_hash  on pg

BEGIN;

SELECT verify_function ('object_store_private.tg_generate_id_hash'); 
SELECT verify_trigger ('object_store_public.generate_id_hash');

ROLLBACK;
