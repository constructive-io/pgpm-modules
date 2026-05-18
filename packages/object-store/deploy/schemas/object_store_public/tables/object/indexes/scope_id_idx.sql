-- Deploy schemas/object_store_public/tables/object/indexes/scope_id_idx to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table

BEGIN;

CREATE INDEX scope_id_idx ON object_store_public.object (
    scope_id
);

COMMIT;
