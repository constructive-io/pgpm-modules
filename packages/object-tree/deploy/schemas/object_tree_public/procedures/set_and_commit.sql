-- Deploy schemas/object_tree_public/procedures/set_and_commit to pg

-- requires: schemas/object_tree_public/schema
-- requires: schemas/object_tree_public/tables/commit/table
-- requires: schemas/object_tree_public/tables/ref/table
-- requires: schemas/object_tree_public/tables/store/table

BEGIN;

-- One-entry wrapper over object_tree_public.set_many_and_commit, which is
-- created later in the plan and resolved at call time.
CREATE FUNCTION object_tree_public.set_and_commit(
  s_id uuid,
  store_id uuid,
  refname text,
  path text[],
  data jsonb,
  kids uuid[],
  ktree text[],
  message text DEFAULT NULL
) returns object_tree_public.commit as $$
BEGIN

RETURN object_tree_public.set_many_and_commit(
  s_id := s_id,
  store_id := set_and_commit.store_id,
  refname := set_and_commit.refname,
  message := set_and_commit.message,
  entries := jsonb_build_array(
    jsonb_build_object(
      'path', coalesce(to_jsonb(set_and_commit.path), '[]'::jsonb),
      'kids', to_jsonb(set_and_commit.kids),
      'ktree', to_jsonb(set_and_commit.ktree)
    ) ||
    -- an absent key means "no data", which is not the same node as one whose
    -- data is the json value null
    CASE WHEN set_and_commit.data IS NULL THEN
      '{}'::jsonb
    ELSE
      jsonb_build_object('data', set_and_commit.data)
    END
  )
);
END;
$$
LANGUAGE 'plpgsql' VOLATILE;


-- Writes one node's data while keeping the children it already has, then
-- commits. Not expressible through set_many_and_commit: the batched primitive
-- takes a node's children as given (an absent kids/ktree means "no children"),
-- whereas this reads the existing node to carry them over.
--
-- Takes the ref FOR UPDATE for the same reason set_many_and_commit does: read
-- ref, compute, repoint is a lost update between concurrent writers to one ref.
CREATE FUNCTION object_tree_public.set_props_and_commit(
  s_id uuid,
  store_id uuid,
  refname text,
  path text[],
  data jsonb,
  message text DEFAULT NULL
) returns object_tree_public.commit as $$
DECLARE
  tree uuid;

  ref object_tree_public.ref;
  com object_tree_public.commit; 

BEGIN

SELECT * INTO ref FROM
  object_tree_public.ref r
    WHERE r.scope_id = s_id
    AND r.store_id = set_props_and_commit.store_id
    AND r.name = refname
FOR UPDATE;

IF (NOT FOUND) THEN
  RAISE EXCEPTION 'REF_NOT_FOUND';
END IF;

SELECT * FROM
  object_tree_public.commit c
    WHERE c.scope_id = s_id
    AND c.store_id = set_props_and_commit.store_id
    AND c.id = ref.commit_id
INTO com;

IF (NOT FOUND) THEN
  RAISE EXCEPTION 'COMMIT_NOT_FOUND';
END IF;

SELECT * FROM
  object_store_public.set_data_at_path
  (s_id, com.tree_id, path, data)
INTO tree;

INSERT INTO object_tree_public.commit (
  scope_id,
  store_id,
  message,
  parent_ids,
  tree_id
) VALUES (s_id, set_props_and_commit.store_id, set_props_and_commit.message, ARRAY[com.id]::uuid[], tree)
RETURNING * INTO com;

UPDATE object_tree_public.ref r
  SET commit_id = com.id 
WHERE r.id = ref.id;

UPDATE object_tree_public.store s
  SET hash = tree
WHERE s.id = set_props_and_commit.store_id
  AND s.scope_id = s_id;

RETURN com;
END;
$$
LANGUAGE 'plpgsql' VOLATILE;


COMMIT;
