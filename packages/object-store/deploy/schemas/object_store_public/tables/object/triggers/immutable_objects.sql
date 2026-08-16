-- Deploy schemas/object_store_public/tables/object/triggers/immutable_objects to pg
-- requires: schemas/object_store_private/schema
-- requires: schemas/object_store_public/tables/object/table

BEGIN;
CREATE FUNCTION object_store_private.tg_immutable_objects ()
    RETURNS TRIGGER
    AS $$
BEGIN
    IF tg_op = 'UPDATE' THEN
        IF (OLD.frzn IS FALSE AND NEW.frzn IS TRUE) THEN
            -- that's ok...
        ELSE
            RAISE EXCEPTION 'you cannot mutate an immutable record.';
        END IF;
    END IF;
    IF tg_op = 'DELETE' THEN
        IF (OLD.frzn IS TRUE) THEN
            RAISE EXCEPTION 'you cannot delete an immutable record.';
        END IF;
        -- A BEFORE DELETE trigger returning NULL cancels the delete: returning
        -- NEW here made every delete of an unfrozen object a silent no-op
        -- (DELETE 0, row still there).
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

CREATE TRIGGER immutable_objects
    BEFORE UPDATE ON object_store_public.object
    FOR EACH ROW
    -- we're hacking this because we need to use DO UPDATE ON CONFLICT to use RETURNING id
    -- if we didn't have a when, it triggers update... which we don't want otherwise we have
    -- to write our own upsert functions (see insert_node_at_path)
    WHEN (NEW.id <> OLD.id OR NEW.data <> OLD.data OR NEW.kids <> OLD.kids OR NEW.ktree <> OLD.ktree)
    EXECUTE PROCEDURE object_store_private.tg_immutable_objects ();

CREATE TRIGGER delete_immutable_objects
    BEFORE DELETE ON object_store_public.object
    FOR EACH ROW
    EXECUTE PROCEDURE object_store_private.tg_immutable_objects ();


COMMIT;

