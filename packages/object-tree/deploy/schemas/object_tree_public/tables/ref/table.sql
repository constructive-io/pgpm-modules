-- Deploy schemas/object_tree_public/tables/ref/table to pg

-- requires: schemas/object_tree_public/schema

BEGIN;

CREATE TABLE object_tree_public.ref (
    id uuid NOT NULL DEFAULT uuidv7(),
    name text NOT NULL,
    scope_id uuid NOT NULL,
    store_id uuid NOT NULL,
    commit_id uuid,
    PRIMARY KEY (id, scope_id)
);

COMMENT ON TABLE object_tree_public.ref IS 'A ref is a data structure for pointing to a commit.';

COMMENT ON COLUMN object_tree_public.ref.id IS 'The primary unique identifier for the ref.';

COMMENT ON COLUMN object_tree_public.ref.name IS 'The name of the ref or branch';

COMMIT;
