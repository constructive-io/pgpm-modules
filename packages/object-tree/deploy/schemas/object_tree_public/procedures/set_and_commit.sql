-- Deploy schemas/object_tree_public/procedures/set_and_commit to pg

-- requires: schemas/object_tree_public/schema
-- requires: schemas/object_tree_public/tables/commit/table
-- requires: schemas/object_tree_public/tables/ref/table

BEGIN;

CREATE FUNCTION object_tree_public.set_and_commit(
  s_id uuid,
  store_id uuid,
  refname text,
  path text[],
  data jsonb,
  kids uuid[],
  ktree text[]
) returns uuid as $$
DECLARE
  hash uuid;

  ref object_tree_public.ref;
  com object_tree_public.commit; 

BEGIN

SELECT * FROM
  object_tree_public.ref r
    WHERE r.scope_id = s_id
    AND r.store_id = set_and_commit.store_id
    AND r.name = refname
INTO ref;

IF (NOT FOUND) THEN
  RAISE EXCEPTION 'REF_NOT_FOUND';
END IF;

SELECT * FROM
  object_tree_public.commit c
    WHERE c.scope_id = s_id
    AND c.store_id = set_and_commit.store_id
    AND c.id = ref.commit_id
INTO com;

IF (NOT FOUND) THEN
  RAISE EXCEPTION 'COMMIT_NOT_FOUND';
END IF;

SELECT * FROM
  object_store_public.insert_node_at_path
  (
    s_id := s_id,
    root := com.tree_id,
    path := set_and_commit.path,
    data := set_and_commit.data,
    kids := set_and_commit.kids,
    ktree := set_and_commit.ktree
  )
INTO hash;

INSERT INTO object_tree_public.commit (
  scope_id,
  store_id,
  message,
  parent_ids,
  tree_id
) VALUES (s_id, set_and_commit.store_id, NOW(), ARRAY[com.id]::uuid[], hash)
RETURNING * INTO com;

UPDATE object_tree_public.ref r
  SET commit_id = com.id 
WHERE r.id = ref.id;

RETURN hash;
END;
$$
LANGUAGE 'plpgsql' VOLATILE;


CREATE FUNCTION object_tree_public.set_props_and_commit(
  s_id uuid,
  store_id uuid,
  refname text,
  path text[],
  data jsonb
) returns uuid as $$
DECLARE
  hash uuid;

  ref object_tree_public.ref;
  com object_tree_public.commit; 

BEGIN

SELECT * FROM
  object_tree_public.ref r
    WHERE r.scope_id = s_id
    AND r.store_id = set_props_and_commit.store_id
    AND r.name = refname
INTO ref;

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
INTO hash;

INSERT INTO object_tree_public.commit (
  scope_id,
  store_id,
  message,
  parent_ids,
  tree_id
) VALUES (s_id, set_props_and_commit.store_id, NOW(), ARRAY[com.id]::uuid[], hash)
RETURNING * INTO com;

UPDATE object_tree_public.ref r
  SET commit_id = com.id 
WHERE r.id = ref.id;

RETURN hash;
END;
$$
LANGUAGE 'plpgsql' VOLATILE;


COMMIT;
