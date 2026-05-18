-- Deploy schemas/object_store_public/tables/object/indexes/object_kids_idx to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table

BEGIN;

CREATE INDEX object_kids_idx ON object_store_public.object USING GIN (
    kids
);

COMMIT;
