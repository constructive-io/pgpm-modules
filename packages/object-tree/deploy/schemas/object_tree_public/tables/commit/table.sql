-- Deploy schemas/object_tree_public/tables/commit/table to pg
-- requires: schemas/object_tree_public/schema

BEGIN;
CREATE TABLE object_tree_public.commit (
  id uuid NOT NULL DEFAULT uuidv7(),
  message text,
  scope_id uuid NOT NULL,
  store_id uuid NOT NULL,
  parent_ids uuid[],
  author_id uuid,
  committer_id uuid,
  tree_id uuid,
  date timestamptz NOT NULL DEFAULT current_timestamp,
  PRIMARY KEY (id, scope_id)
);
COMMENT ON TABLE object_tree_public.commit IS 'A commit records changes to the repository.';
COMMENT ON COLUMN object_tree_public.commit.id IS 'The primary unique identifier for the commit.';
COMMENT ON COLUMN object_tree_public.commit.message IS 'The commit message';
COMMENT ON COLUMN object_tree_public.commit.parent_ids IS 'Parent commits';
COMMENT ON COLUMN object_tree_public.commit.scope_id IS 'The scope identifier';
COMMENT ON COLUMN object_tree_public.commit.tree_id IS 'The root of the tree';
COMMENT ON COLUMN object_tree_public.commit.author_id IS 'The author of the commit';
COMMENT ON COLUMN object_tree_public.commit.committer_id IS 'The committer of the commit';

COMMIT;

