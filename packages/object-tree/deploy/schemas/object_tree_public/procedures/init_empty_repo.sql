-- Deploy schemas/object_tree_public/procedures/init_empty_repo to pg

-- requires: schemas/object_tree_public/schema
-- requires: schemas/object_tree_public/tables/commit/table
-- requires: schemas/object_tree_public/tables/ref/table
-- requires: schemas/object_tree_public/tables/store/table

BEGIN;

CREATE FUNCTION object_tree_public.init_empty_repo(
  s_id uuid,
  store_id uuid
) returns void as $$
DECLARE
  vtree_id uuid;
  vcommit_id uuid;
  vref_id uuid;
BEGIN

  -- Check for existing commits in this store
  IF EXISTS (SELECT 1 FROM object_tree_public.commit c WHERE c.scope_id = s_id AND c.store_id = init_empty_repo.store_id) THEN 
      RAISE EXCEPTION 'REPO_EXISTS';
  END IF;

    INSERT INTO object_store_public.object (scope_id)
      VALUES (s_id)
  RETURNING id INTO vtree_id;

    INSERT INTO object_tree_public.ref (scope_id, store_id, name)
      VALUES (s_id, init_empty_repo.store_id, 'main')
  RETURNING id INTO vref_id;

    INSERT INTO object_tree_public.commit (scope_id, store_id, message, tree_id)
      VALUES (s_id, init_empty_repo.store_id, 'first commit', vtree_id)
  RETURNING id into vcommit_id;

  UPDATE object_tree_public.ref SET commit_id = vcommit_id
    WHERE id = vref_id;

  -- the store's head tree, kept current from here on by the commit functions
  UPDATE object_tree_public.store s SET hash = vtree_id
    WHERE s.id = init_empty_repo.store_id
      AND s.scope_id = s_id;

END;
$$
LANGUAGE 'plpgsql' VOLATILE;

COMMIT;
