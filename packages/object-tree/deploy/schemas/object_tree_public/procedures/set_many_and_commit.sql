-- Deploy schemas/object_tree_public/procedures/set_many_and_commit to pg

-- requires: schemas/object_tree_public/schema
-- requires: schemas/object_tree_public/tables/commit/table
-- requires: schemas/object_tree_public/tables/ref/table

BEGIN;

-- Apply a whole set of writes to a ref and record them as one commit.
--
-- entries is [{ "path": ["a","b"], "data": {...} }, ...]; an entry may also
-- carry "kids" and "ktree" to write a node's children explicitly. Entries are
-- applied in order, so a repeated path is last-write-wins, and the ref moves
-- once: one call is one commit, not one commit per write. Nothing to write
-- leaves the ref untouched and returns the commit the ref already points at.
--
-- Returns the commit row rather than the new tree id: a caller that only wants
-- the tree reads .tree_id, and a caller stamping provenance (every generated
-- merkle writer does) gets .id without re-reading the ref. This is the same
-- shape the generated stores' {prefix}set_many_and_commit returns.
CREATE FUNCTION object_tree_public.set_many_and_commit (s_id uuid, store_id uuid, refname text, entries jsonb, message text DEFAULT NULL)
  RETURNS object_tree_public.commit
  AS $$
DECLARE
  hash uuid;
  paths jsonb;
  datas jsonb[];
  kids_list jsonb;
  ktree_list jsonb;
  ref object_tree_public.ref;
  com object_tree_public.commit;
BEGIN
  SELECT
    *
  FROM
    object_tree_public.ref AS r
  WHERE
    r.scope_id = s_id
    AND r.store_id = set_many_and_commit.store_id
    AND r.name = refname INTO ref;
  IF (NOT FOUND) THEN
    RAISE EXCEPTION 'REF_NOT_FOUND';
  END IF;
  SELECT
    *
  FROM
    object_tree_public.commit AS c
  WHERE
    c.scope_id = s_id
    AND c.store_id = set_many_and_commit.store_id
    AND c.id = ref.commit_id INTO com;
  IF (NOT FOUND) THEN
    RAISE EXCEPTION 'COMMIT_NOT_FOUND';
  END IF;
  IF (entries IS NULL OR jsonb_array_length(entries) = 0) THEN
    RETURN com;
  END IF;
  SELECT
    jsonb_agg(e.value -> 'path' ORDER BY e.ord),
    array_agg(e.value -> 'data' ORDER BY e.ord),
    jsonb_agg(coalesce(e.value -> 'kids', 'null'::jsonb) ORDER BY e.ord),
    jsonb_agg(coalesce(e.value -> 'ktree', 'null'::jsonb) ORDER BY e.ord)
  FROM jsonb_array_elements(set_many_and_commit.entries) WITH ORDINALITY AS e (value, ord) INTO paths,
  datas,
  kids_list,
  ktree_list;
  SELECT
    *
  FROM
    object_store_public.insert_nodes_at_paths (s_id := s_id, root := com.tree_id, paths := paths, datas := datas, kids_list := kids_list, ktree_list := ktree_list) INTO hash;
  INSERT INTO object_tree_public.commit (scope_id, store_id, message, parent_ids, tree_id)
    VALUES (s_id, set_many_and_commit.store_id, set_many_and_commit.message, ARRAY[com.id]::uuid[], hash)
  RETURNING
    * INTO com;
  UPDATE
    object_tree_public.ref AS r
  SET
    commit_id = com.id
  WHERE
    r.id = ref.id;
  RETURN com;
END;
$$
LANGUAGE plpgsql
VOLATILE;

COMMIT;
