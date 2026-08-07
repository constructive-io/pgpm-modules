-- Verify schemas/object_store_public/tables/object/triggers/generate_id_hash  on pg

BEGIN;

SELECT assert_function('object_store_private.tg_generate_id_hash()'::regprocedure);
SELECT assert_trigger('object_store_public.object'::regclass, 'generate_id_hash', 'object_store_private.tg_generate_id_hash'::regproc, 7);

ROLLBACK;
