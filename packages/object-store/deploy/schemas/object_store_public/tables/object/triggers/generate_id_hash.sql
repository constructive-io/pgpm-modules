-- Deploy schemas/object_store_public/tables/object/triggers/generate_id_hash to pg
-- requires: schemas/object_store_private/schema
-- requires: schemas/object_store_public/tables/object/table
-- requires: schemas/object_store_private/procedures/object_hash_uuid 

BEGIN;
CREATE FUNCTION object_store_private.tg_generate_id_hash ()
    RETURNS TRIGGER
    AS $$
BEGIN
    NEW.id = object_store_public.object_hash_uuid (NEW);
    RETURN NEW;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;
CREATE TRIGGER generate_id_hash
    BEFORE INSERT ON object_store_public.object
    FOR EACH ROW
    EXECUTE PROCEDURE object_store_private.tg_generate_id_hash ();
COMMIT;

