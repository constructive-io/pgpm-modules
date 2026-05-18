-- Deploy schemas/object_tree_public/tables/ref/indexes/idx_unique_object_ref_name to pg

-- requires: schemas/object_tree_public/schema
-- requires: schemas/object_tree_public/tables/ref/table

BEGIN;

CREATE UNIQUE INDEX idx_unique_object_ref_name ON object_tree_public.ref (
    store_id, DECODE(MD5(LOWER(name)), 'hex')
);

COMMIT;
