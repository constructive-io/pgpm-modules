-- Deploy schemas/object_tree_public/tables/store/table to pg

-- requires: schemas/object_tree_public/schema

BEGIN;

CREATE TABLE object_tree_public.store (
  id uuid NOT NULL DEFAULT uuidv7(),
  name text NOT NULL,
  scope_id uuid NOT NULL,
  hash uuid,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);

COMMENT ON TABLE object_tree_public.store IS 'A store represents an isolated object repository within a database.';
COMMENT ON COLUMN object_tree_public.store.id IS 'The primary unique identifier for the store.';
COMMENT ON COLUMN object_tree_public.store.name IS 'The name of the store (e.g., metaschema, migrations).';
COMMENT ON COLUMN object_tree_public.store.scope_id IS 'The scope this store belongs to.';
COMMENT ON COLUMN object_tree_public.store.hash IS 'The current head tree_id for this store.';

CREATE UNIQUE INDEX idx_unique_store_name ON object_tree_public.store (
  scope_id, DECODE(MD5(LOWER(name)), 'hex')
);

COMMIT;
