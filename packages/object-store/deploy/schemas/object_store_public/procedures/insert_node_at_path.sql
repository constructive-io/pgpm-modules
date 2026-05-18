-- Deploy schemas/object_store_public/procedures/insert_node_at_path to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table
-- requires: schemas/object_store_utils/procedures/array_index_of
-- requires: schemas/object_store_utils/procedures/array_utils

BEGIN;

CREATE FUNCTION object_store_public.insert_node_at_path (s_id uuid, root uuid, path text[], data jsonb, kids uuid[], ktree text[])
  RETURNS uuid
  AS $$
DECLARE
  _newnode_id uuid;
  _newparent_id uuid;
  _parent object_store_public.object;
  _orig_name text;
  _repl uuid;
  _uuid_to_return uuid;
  _parent_existed bool;

  vkids uuid[];
  vktree text[];

  i int;
  _path_len int;
  _depth int;
  _pos int;
  _cur_id uuid;
  _cur_obj object_store_public.object;

  -- Cached nodes along the path for O(D) bottom-up rebuild.
  -- Index 1 = root (depth 0), index k+1 = node at path[1..k] (depth k).
  _cached object_store_public.object[];

  children_hash jsonb;

BEGIN

  _path_len = coalesce(array_length(path, 1), 0);

  -- STEP 1: Walk down the path from root, caching each node.
  -- Replaces O(D) call to get_node_at_path AND pre-populates the
  -- cache so the bottom-up rebuild avoids re-walking from root
  -- at each level (eliminates the O(D²) repeated walks).

  SELECT * FROM object_store_public.object o
    WHERE o.id = insert_node_at_path.root
    AND o.scope_id = s_id
  INTO _cur_obj;

  _cached[1] = _cur_obj;
  _depth = 0;

  IF (_cur_obj.id IS NOT NULL AND _path_len > 0) THEN
    FOR i IN 1.._path_len LOOP
      _pos = object_store_utils.array_index_of(_cur_obj.ktree, path[i]);
      IF (_pos > 0) THEN
        _cur_id = _cur_obj.kids[_pos];
        SELECT * FROM object_store_public.object o
          WHERE o.id = _cur_id
          AND o.scope_id = s_id
        INTO _cur_obj;
        _cached[i + 1] = _cur_obj;
        _depth = i;
      ELSE
        EXIT;
      END IF;
    END LOOP;
  END IF;

  -- STEP 2: Insert the new node
  INSERT INTO object_store_public.object (scope_id, data, kids, ktree)
    VALUES (s_id, insert_node_at_path.data, insert_node_at_path.kids, insert_node_at_path.ktree)
    ON CONFLICT (id, scope_id)
      DO UPDATE  -- DO NOT USE NOTHING! won't return an ID
      SET scope_id = EXCLUDED.scope_id
  RETURNING
    id
  INTO _newnode_id;

  IF (_newnode_id IS NULL) THEN
    RAISE EXCEPTION '_newnode_id failed';
  END IF;

  _orig_name = path[_path_len];
  _repl = _newnode_id;
  _uuid_to_return = _newnode_id;

  -- STEP 3: Walk back up, creating new parent nodes with updated children.
  -- Each parent is read from _cached instead of re-walking from root.
  FOR i IN REVERSE _path_len..1 LOOP

    -- Parent is at depth i-1, stored in _cached[i]
    IF (i - 1 = 0) THEN
      _parent = _cached[1];
      _parent_existed = ((_parent).id IS NOT NULL);
    ELSIF (i - 1 <= _depth) THEN
      _parent = _cached[i];
      _parent_existed = TRUE;
    ELSE
      _parent_existed = FALSE;
    END IF;

    IF (_parent_existed) THEN

      -- Update parent's children: jsonb_set replaces if key exists, adds if not
      children_hash = object_store_utils.zip_arrays(
        _parent.ktree,
        _parent.kids
      );

      children_hash = jsonb_set(children_hash, ARRAY[_orig_name]::text[], to_jsonb(_repl));

      SELECT h.ktree, h.kids FROM object_store_utils.unzip_obj_to_ktree_and_kids(
        children_hash
      ) h INTO vktree, vkids;

      INSERT INTO object_store_public.object (scope_id, data, kids, ktree)
        VALUES (s_id, _parent.data, vkids, vktree)
      ON CONFLICT (id, scope_id)
        DO UPDATE  -- DO NOT USE NOTHING! won't return an ID
        SET scope_id = EXCLUDED.scope_id
      RETURNING
        id
      INTO _newparent_id;

      IF (_newparent_id IS NULL) THEN
        RAISE EXCEPTION 'parent insert failed at depth %', i - 1;
      END IF;

    ELSE

      -- Parent doesn't exist: create new node with single child
      INSERT INTO object_store_public.object (scope_id, data, kids, ktree)
        VALUES (s_id, NULL, ARRAY[_repl]::uuid[], ARRAY[_orig_name]::text[])
      ON CONFLICT (id, scope_id)
        DO UPDATE  -- DO NOT USE NOTHING! won't return an ID
        SET scope_id = EXCLUDED.scope_id
      RETURNING
        id
      INTO _newparent_id;

    END IF;

    -- Move up: this parent becomes the child for the next level
    _orig_name = path[i - 1];
    _repl = _newparent_id;
    _uuid_to_return = _newparent_id;

  END LOOP;

  RETURN _uuid_to_return;
END;
$$
LANGUAGE plpgsql
VOLATILE;
COMMIT;
