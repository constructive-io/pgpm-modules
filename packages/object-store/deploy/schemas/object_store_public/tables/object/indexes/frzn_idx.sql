-- Deploy schemas/object_store_public/tables/object/indexes/frzn_idx to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table

BEGIN;

-- used for deletion mostly

CREATE INDEX frzn_idx ON object_store_public.object (
    frzn
);

COMMIT;
