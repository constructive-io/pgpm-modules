\echo Use "CREATE EXTENSION object-store" to load this file. \quit
CREATE SCHEMA object_store_private;

GRANT USAGE ON SCHEMA object_store_private TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_private
  GRANT EXECUTE ON FUNCTIONS TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_private
  GRANT ALL ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_private
  GRANT ALL ON TABLES TO authenticated;

CREATE SCHEMA object_store_public;

GRANT USAGE ON SCHEMA object_store_public TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_public
  GRANT EXECUTE ON FUNCTIONS TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_public
  GRANT ALL ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_public
  GRANT ALL ON TABLES TO authenticated;

CREATE SCHEMA object_store_utils;

GRANT USAGE ON SCHEMA object_store_utils TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_utils
  GRANT EXECUTE ON FUNCTIONS TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_utils
  GRANT ALL ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_store_utils
  GRANT ALL ON TABLES TO authenticated;

CREATE FUNCTION object_store_utils.array_get_last(
  arr anyarray
) RETURNS anyelement AS $EOFCODE$
  SELECT arr[array_length(arr, 1)];
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION object_store_utils.array_index_of(
  arr anyarray,
  el anyelement
) RETURNS int AS $EOFCODE$ 
DECLARE
  val int = -1;
  i int;
BEGIN
  FOR i IN SELECT * FROM generate_subscripts(arr, 1) g(i)
  LOOP
    IF (el = arr[i]) THEN
      val = i;
      RETURN val;
    END IF;
  END LOOP;
  RETURN val;
END
$EOFCODE$ LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION object_store_utils.array_pop(
  srcarr anyarray
) RETURNS SETOF anyarray AS $EOFCODE$ 
SELECT ARRAY (
 SELECT UNNEST(srcarr) LIMIT (
  SELECT array_upper(srcarr, 1) - 1
 )
)
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION object_store_utils.array_shift(
  srcarr anyarray
) RETURNS SETOF anyarray AS $EOFCODE$ 
SELECT srcarr[2:array_length(srcarr, 1)]
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION object_store_utils.zip_arrays(
  a text[],
  b anyarray
) RETURNS jsonb AS $EOFCODE$
DECLARE
  obj jsonb;
BEGIN
	IF (cardinality(a) != cardinality(b)) THEN 
		RAISE EXCEPTION 'cannot zip arrays of different cardinality';
	END IF;

	-- A null key is a hard error and a null value makes the whole object
	-- null, as the equivalent per-element jsonb_set chain did (a null path
	-- element raises; to_jsonb and jsonb_set are strict).
	IF EXISTS (
		SELECT 1 FROM generate_series(1, cardinality(a)) AS i WHERE a[i] IS NULL
	) THEN
		RAISE EXCEPTION 'cannot zip arrays with a null key';
	END IF;

	IF EXISTS (
		SELECT 1 FROM generate_series(1, cardinality(a)) AS i WHERE b[i] IS NULL
	) THEN
		RETURN NULL;
	END IF;

	-- Later duplicate keys win, matching the assignment order of the loop.
	SELECT coalesce(jsonb_object_agg(a[i], to_jsonb(b[i]::text) ORDER BY i), '{}'::jsonb)
	  INTO obj
	  FROM generate_series(1, cardinality(a)) AS i;

	RETURN obj;
END;
$EOFCODE$ LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION object_store_utils.unzip_obj_to_ktree_and_kids(
  obj jsonb
) RETURNS TABLE (
  ktree text[],
  kids uuid[]
) AS $EOFCODE$
BEGIN
	-- Aggregated in jsonb_each_text's own emission order, the order the
	-- per-key append loop produced; both arrays feed the node hash.
	SELECT array_agg(e.key), array_agg(e.value::uuid)
	  INTO ktree, kids
	  FROM jsonb_each_text(obj) AS e;

	RETURN next;
END;
$EOFCODE$ LANGUAGE plpgsql IMMUTABLE;

CREATE TABLE object_store_public.object (
  id uuid NOT NULL,
  scope_id uuid NOT NULL,
  kids uuid[],
  ktree text[],
  data jsonb,
  frzn bool DEFAULT false,
  created_at timestamptz DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id, scope_id),
  CONSTRAINT kids_ktree_length_match 
    CHECK (
    cardinality(kids) = cardinality(ktree)
      OR (kids IS NULL
      AND ktree IS NULL)
  )
);

CREATE FUNCTION object_store_public.get_all_objects_from_root(
  s_id uuid,
  id uuid
) RETURNS SETOF object_store_public.object AS $EOFCODE$ WITH RECURSIVE hierarchy AS (
    SELECT
        *
    FROM
        object_store_public.object o
    WHERE
        o.id = get_all_objects_from_root.id AND o.scope_id=s_id
    UNION
    SELECT
        object.*
    FROM
        object_store_public.object AS object
        JOIN hierarchy a ON (object.id = ANY (a.kids) AND object.scope_id=a.scope_id))
SELECT
    *
FROM
    hierarchy;
$EOFCODE$ LANGUAGE sql STABLE;

CREATE FUNCTION object_store_public.get_all(
  s_id uuid,
  id uuid
) RETURNS TABLE (
  path text[],
  data jsonb
) AS $EOFCODE$ 
DECLARE
  root object_store_public.object;
  pth text[];
  i int;
  
  cid uuid;
  cname text;
  
  rpath text[];
  rdata jsonb;
BEGIN

		SELECT * from object_store_public.object o WHERE o.scope_id = s_id
				AND o.id = get_all.id
	INTO root;
			
	pth = ARRAY[]::text[];
	
  	FOR i IN
  	SELECT * FROM generate_series(1, cardinality(root.kids))
  	LOOP
  	     cid = root.kids[i];
  	     cname = root.ktree[i];
  	     
  	     FOR rpath, rdata IN
  	     SELECT * FROM object_store_public.get_all(s_id, cid)
  	     LOOP 
		      path := ARRAY[cname] || rpath;	
 	  	    data := rdata;
  	 	  	  RETURN next; 	 	     
  	     END LOOP;
  	     
  	END LOOP;

  path := ARRAY[]::text[];	
 	data := root.data; 		
	RETURN next;	


END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION object_store_public.get_node_at_path(
  s_id uuid,
  id uuid,
  path text[] DEFAULT CAST(ARRAY[] AS text[])
) RETURNS object_store_public.object AS $EOFCODE$ 

DECLARE
  _path text[] = path;
  _obj object_store_public.object;

  i int;
  pos int;
  curpath text;

  _node text;
  _node_id uuid;
BEGIN

  SELECT * FROM object_store_public.object o
    WHERE o.id = get_node_at_path.id
    AND o.scope_id = s_id
  INTO _obj;

  IF (array_length(_path, 1) > 0) THEN
    FOR i IN SELECT * FROM generate_subscripts(_path, 1) g(i)
    LOOP

      curpath = _path[1];
      pos = object_store_utils.array_index_of(_obj.ktree, curpath);

      IF (pos > 0) THEN
        _node_id = _obj.kids[pos];
        SELECT * FROM object_store_public.object o
          WHERE o.id = _node_id
          AND o.scope_id = s_id
        INTO _obj;
        -- TODO check if 1 is correct
        -- NOTE is only NULL, not 0 for whatver reason if you need to use that...
        -- IF (array_length(_path, 1) IS NULL) THEN
        IF (array_length(_path, 1) = 1) THEN
            RETURN _obj;
        END IF;

      END IF;
      _path = object_store_utils.array_shift(_path);
    END LOOP;
  ELSE
    RETURN _obj;
  END IF;

  RETURN NULL;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION object_store_public.get_path_objects_from_root(
  s_id uuid,
  id uuid,
  path text[] DEFAULT CAST(ARRAY[] AS text[])
) RETURNS SETOF object_store_public.object AS $EOFCODE$ 

DECLARE
  _path text[] = path;
  _obj object_store_public.object;

  i int;
  pos int;
  curpath text;

  _node text;
  _node_id uuid;
BEGIN

  SELECT * FROM object_store_public.object o
    WHERE o.id = get_path_objects_from_root.id
    AND o.scope_id = s_id
  INTO _obj;
  RETURN NEXT _obj;

  FOR i IN SELECT * FROM generate_subscripts(_path, 1) g(i)
  LOOP

    curpath = _path[1];
    pos = object_store_utils.array_index_of(_obj.ktree, curpath);

    IF (pos > 0) THEN
      _node_id = _obj.kids[pos];
      SELECT * FROM object_store_public.object o
        WHERE o.id = _node_id
        AND o.scope_id = s_id
      INTO _obj;
      RETURN NEXT _obj;

    END IF;
    _path = object_store_utils.array_shift(_path);
  END LOOP;

END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION object_store_public.insert_node_at_path(
  s_id uuid,
  root uuid,
  path text[],
  data jsonb,
  kids uuid[],
  ktree text[]
) RETURNS uuid AS $EOFCODE$
BEGIN
  RETURN object_store_public.insert_nodes_at_paths (s_id := insert_node_at_path.s_id, root := insert_node_at_path.root, paths := jsonb_build_array(coalesce(to_jsonb(insert_node_at_path.path), '[]'::jsonb)), datas := ARRAY[insert_node_at_path.data]::jsonb[], kids_list := jsonb_build_array(to_jsonb(insert_node_at_path.kids)), ktree_list := jsonb_build_array(to_jsonb(insert_node_at_path.ktree)));
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION object_store_public.object_hash_uuid(
  obj object_store_public.object
) RETURNS uuid AS $EOFCODE$
DECLARE
  _cash jsonb = '{}'::jsonb;
  hash1 uuid;
  hash2 uuid;
BEGIN
  IF (obj.data IS NOT NULL) THEN
    hash1 = uuid_generate_v5 (uuid_ns_url (), obj.data::text);
  END IF;

  IF (obj.kids IS NOT NULL AND obj.ktree IS NOT NULL) THEN
    -- TODO for future feature, this is where you can put an IF statement to allow order. Not sure where to put the meta data for allowing order, but could be as simple as a bool field on all objects called "order"
    -- _cash is the children hash, it is ordered using jsonb lexically
    _cash =  json_object(obj.ktree::text[], obj.kids::text[]);
    hash2 = uuid_generate_v5 (uuid_ns_url (), _cash::text);
  END IF;

  RETURN uuid_generate_v5 (uuid_ns_url (), concat(hash1, hash2)::text);
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION object_store_public.remove_node_at_path(
  s_id uuid,
  root uuid,
  path text[]
) RETURNS uuid AS $EOFCODE$
DECLARE
  _node object_store_public.object;
  _parent object_store_public.object;

  _newparent_id uuid;
  _path text[] = path;

  child_to_remove text;

  vkids uuid[];
  vktree text[];
  children_hash jsonb;
BEGIN

    IF (cardinality(path) < 1) THEN 
      RAISE EXCEPTION 'cannot remove root node';
    END IF;


  -- STEP 1
  -- check if it exists
  SELECT
    *
  FROM
    object_store_public.get_node_at_path
     (s_id, root, path)
  INTO _node;

  -- NOTE cannot use FOUND/NOT FOUND here
  IF (_node.id IS NULL) THEN
    RETURN root;
  END IF;

  -- STEP 2(a) get child to remove
  child_to_remove = object_store_utils.array_get_last(_path);

  -- STEP 2(b) get parent
  _path = object_store_utils.array_pop(_path);

  SELECT
    *
  FROM
    object_store_public.get_node_at_path
    (s_id, root, _path)
  INTO _parent;

  children_hash = object_store_utils.zip_arrays(
    _parent.ktree,
    _parent.kids
  );

  children_hash = children_hash - child_to_remove;

  SELECT h.ktree, h.kids FROM object_store_utils.unzip_obj_to_ktree_and_kids(
    children_hash
  ) h INTO vktree, vkids;


  -- STEP 3 update new parent
  RETURN object_store_public.insert_node_at_path(
    s_id,
    root,
    _path,
    _parent.data,
    vkids,
    vktree
  );

END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION object_store_public.update_node_at_path(
  s_id uuid,
  root uuid,
  path text[],
  data jsonb,
  kids uuid[],
  ktree text[]
) RETURNS uuid AS $EOFCODE$
BEGIN
  RETURN object_store_public.insert_node_at_path(s_id, root, path, data, kids, ktree);
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION object_store_public.set_data_at_path(
  s_id uuid,
  root uuid,
  path text[],
  data jsonb
) RETURNS uuid AS $EOFCODE$
DECLARE
  _node object_store_public.object;
  _kids uuid[] = ARRAY[]::uuid[];
  _ktree text[] = ARRAY[]::text[];
BEGIN
  -- Look up existing node to preserve its children
  SELECT * FROM object_store_public.get_node_at_path(s_id, root, path)
  INTO _node;

  IF (_node.id IS NOT NULL) THEN
    _kids = _node.kids;
    _ktree = _node.ktree;
  END IF;

  -- Delegate to insert_node_at_path with preserved children
  RETURN object_store_public.insert_node_at_path(
    s_id, root, path, data, _kids, _ktree
  );
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION object_store_public.freeze_objects(
  s_id uuid,
  id uuid
) RETURNS void AS $EOFCODE$
BEGIN

-- Unnest kids so each recursion step joins through the (id, scope_id)
-- primary key instead of scanning the whole table per level.
WITH RECURSIVE hierarchy AS (
    SELECT
        o.id, o.scope_id, o.kids
    FROM
        object_store_public.object o
    WHERE
        o.id = freeze_objects.id AND o.scope_id=s_id
    UNION
    SELECT
        object.id, object.scope_id, object.kids
    FROM
        hierarchy a
        CROSS JOIN LATERAL unnest(a.kids) AS kid(id)
        JOIN object_store_public.object AS object
          ON (object.id = kid.id AND object.scope_id=a.scope_id))

UPDATE object_store_public.object o
  SET frzn = TRUE
FROM hierarchy
  WHERE hierarchy.id = o.id AND hierarchy.scope_id = o.scope_id;

END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE INDEX scope_id_idx ON object_store_public.object (scope_id);

CREATE INDEX frzn_idx ON object_store_public.object (frzn);

CREATE INDEX object_kids_idx ON object_store_public.object USING gin (kids);

CREATE FUNCTION object_store_private.tg_generate_id_hash() RETURNS trigger AS $EOFCODE$
BEGIN
    NEW.id = object_store_public.object_hash_uuid (NEW);
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER generate_id_hash
  BEFORE INSERT
  ON object_store_public.object
  FOR EACH ROW
  EXECUTE PROCEDURE object_store_private.tg_generate_id_hash();

CREATE FUNCTION object_store_private.tg_immutable_objects() RETURNS trigger AS $EOFCODE$
BEGIN
    IF tg_op = 'UPDATE' THEN
        IF (OLD.frzn IS FALSE AND NEW.frzn IS TRUE) THEN
            -- that's ok...
        ELSE
            RAISE EXCEPTION 'you cannot mutate an immutable record.';
        END IF;
    END IF;
    IF tg_op = 'DELETE' THEN
        IF (OLD.frzn IS TRUE) THEN
            RAISE EXCEPTION 'you cannot delete an immutable record.';
        END IF;
        -- A BEFORE DELETE trigger returning NULL cancels the delete: returning
        -- NEW here made every delete of an unfrozen object a silent no-op
        -- (DELETE 0, row still there).
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql;

CREATE TRIGGER immutable_objects
  BEFORE UPDATE
  ON object_store_public.object
  FOR EACH ROW
  WHEN (new.id <> old.id
    OR new.data <> old.data
    OR new.kids <> old.kids
    OR new.ktree <> old.ktree)
  EXECUTE PROCEDURE object_store_private.tg_immutable_objects();

CREATE TRIGGER delete_immutable_objects
  BEFORE DELETE
  ON object_store_public.object
  FOR EACH ROW
  EXECUTE PROCEDURE object_store_private.tg_immutable_objects();

CREATE FUNCTION object_store_private.node_hash_uuid(
  data jsonb,
  kids uuid[],
  ktree text[]
) RETURNS uuid AS $EOFCODE$
  SELECT
    object_store_public.object_hash_uuid (jsonb_populate_record(NULL::object_store_public.object, jsonb_build_object('data', node_hash_uuid.data, 'kids', to_jsonb(node_hash_uuid.kids), 'ktree', to_jsonb(node_hash_uuid.ktree))));
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION object_store_public.insert_nodes_at_paths(
  s_id uuid,
  root uuid,
  paths jsonb,
  datas jsonb[],
  kids_list jsonb DEFAULT NULL,
  ktree_list jsonb DEFAULT NULL
) RETURNS uuid AS $EOFCODE$
DECLARE
  -- every write, deduplicated: key, depth, own name, parent's key, then the
  -- written content. Written content stays jsonb (including a JSON null when
  -- the caller passed nothing) so "no children given" and "empty children
  -- given" remain distinguishable, as they hash differently.
  w_key text[];
  w_depth int[];
  w_name text[];
  w_parent text[];
  w_data jsonb[];
  w_kids jsonb[];
  w_ktree jsonb[];
  -- every dirty directory: every proper prefix of a written path, plus the
  -- root, which every write dirties
  d_key text[];
  d_depth int[];
  d_name text[];
  d_parent text[];
  -- the pre-existing node id of each dirty directory that already exists.
  -- Only the id: a wide directory's children are materialised once, inside the
  -- level query that needs them, never copied through a variable.
  b_key text[] := '{}';
  b_id uuid[] := '{}';
  -- the leaves, already collapsed into one child map per parent directory. The
  -- level loop then never touches anything batch-sized: a directory takes its
  -- children from its own leaf map plus the directories built one level below.
  lp_parent text[];
  lp_children jsonb[];
  -- the writes that are themselves dirty directories — a written path with
  -- deeper writes under it. As many as the batch is deep, not as long as it is,
  -- so the level loop can carry them.
  dw_key text[];
  dw_data jsonb[];
  dw_kids jsonb[];
  dw_ktree jsonb[];
  -- the directories built by the previous (deeper) iteration
  pd_name text[] := '{}';
  pd_parent text[] := '{}';
  pd_id uuid[] := '{}';
  -- the directories built by the current iteration
  l_name text[];
  l_parent text[];
  l_id uuid[];
  root_key CONSTANT text := '[]';
  root_id uuid;
  max_depth int;
  cur_depth int;
BEGIN
  IF (paths IS NULL OR jsonb_array_length(paths) = 0) THEN
    RETURN root;
  END IF;

  -- 1+2. normalise the writes (the last duplicate of a path wins), then derive
  --      every dirty directory: every proper prefix of a written path, plus the
  --      root, which every write dirties
  WITH exploded AS (
    SELECT
      ARRAY (
        SELECT
          jsonb_array_elements_text(e.value))::text[] AS path,
      e.ord::int AS ord,
      d.data
    FROM jsonb_array_elements(insert_nodes_at_paths.paths) WITH ORDINALITY AS e (value, ord)
    LEFT JOIN unnest(insert_nodes_at_paths.datas) WITH ORDINALITY AS d (data, ord) ON d.ord = e.ord
),
  writes AS (
    SELECT DISTINCT ON (to_jsonb(x.path)::text)
      to_jsonb(x.path)::text AS node_key,
      x.path,
      cardinality(x.path) AS depth,
      x.path[cardinality(x.path)] AS name,
      to_jsonb(x.path[1:cardinality(x.path) - 1])::text AS parent,
      x.data,
      coalesce(insert_nodes_at_paths.kids_list -> (x.ord - 1), 'null'::jsonb) AS kids,
      coalesce(insert_nodes_at_paths.ktree_list -> (x.ord - 1), 'null'::jsonb) AS ktree
    FROM exploded AS x
    ORDER BY
      to_jsonb(x.path)::text,
      x.ord DESC
),
  dirs AS (
    SELECT DISTINCT
      to_jsonb(pfx.path)::text AS node_key,
      cardinality(pfx.path) AS depth,
      pfx.path[cardinality(pfx.path)] AS name,
      to_jsonb(pfx.path[1:cardinality(pfx.path) - 1])::text AS parent
    FROM (
      SELECT
        ARRAY[]::text[] AS path
      UNION ALL
      SELECT
        wr.path[1:g.i]
      FROM writes AS wr,
      LATERAL generate_series(1, wr.depth - 1) AS g (i)) AS pfx
)
-- Each group of parallel arrays is aggregated in ONE pass, so every array in
-- the group sees the same row order and stays aligned with its siblings.
  SELECT
    wa.keys,
    wa.depths,
    wa.names,
    wa.parents,
    wa.datas,
    wa.kids,
    wa.ktree,
    da.keys,
    da.depths,
    da.names,
    da.parents,
    da.max_depth
  FROM (
    SELECT
      array_agg(wr.node_key) AS keys,
      array_agg(wr.depth) AS depths,
      array_agg(wr.name) AS names,
      array_agg(wr.parent) AS parents,
      array_agg(wr.data) AS datas,
      array_agg(wr.kids) AS kids,
      array_agg(wr.ktree) AS ktree
    FROM writes AS wr) AS wa,
    (
      SELECT
        array_agg(dr.node_key) AS keys,
        array_agg(dr.depth) AS depths,
        array_agg(dr.name) AS names,
        array_agg(dr.parent) AS parents,
        max(dr.depth) AS max_depth
      FROM dirs AS dr) AS da INTO w_key,
    w_depth,
    w_name,
    w_parent,
    w_data,
    w_kids,
    w_ktree,
    d_key,
    d_depth,
    d_name,
    d_parent,
    max_depth;

  -- 3. resolve each dirty directory against the pre-existing tree, walking down
  --    from the current root so untouched siblings survive the rebuild.
  --
  --    The descent joins a directory to its parent on the parent's key, which
  --    every directory already carries: an equijoin the planner hashes once per
  --    level. Recursing on depth instead and matching with a path-prefix filter
  --    (`child.path[1:r.depth] = r.path`) is the same walk but not a join
  --    condition, so every dirty directory is compared against every row of the
  --    level above — 9.6M filtered comparisons per level on a 22k-directory
  --    batch, each re-deriving the path from the key, which is 300s of a 307s
  --    pass against 0.4s for this one.
  --
  --    The root is the descent's seed, not a child: it is its own parent under
  --    `to_jsonb(path[1:0])`, so leaving it in the recursive side joins it to
  --    itself forever.
  WITH RECURSIVE dirs AS (
    SELECT
      dr.node_key,
      dr.name,
      dr.parent
    FROM unnest(d_key, d_name, d_parent) AS dr (node_key, name, parent)
    WHERE dr.node_key <> root_key
),
  resolved AS (
    SELECT
      root_key AS node_key,
      insert_nodes_at_paths.root AS node_id
    UNION ALL
    SELECT
      child.node_key,
      parent_obj.kids[object_store_utils.array_index_of (parent_obj.ktree, child.name)]
    FROM resolved AS r
    JOIN dirs AS child ON child.parent = r.node_key
    LEFT JOIN object_store_public.object AS parent_obj ON parent_obj.id = r.node_id
      AND parent_obj.scope_id = insert_nodes_at_paths.s_id
)
  SELECT
    coalesce(array_agg(res.node_key), '{}'),
    coalesce(array_agg(res.node_id), '{}')
  FROM resolved AS res
  WHERE res.node_id IS NOT NULL INTO b_key,
    b_id;

  -- 4a. stage the leaves: writes that are not themselves dirty directories.
  --     Their kids/ktree are inserted exactly as given, so a caller passing
  --     empty arrays still hashes the same as the singular path does. Leaves are
  --     the numerous, narrow nodes in a batch, so they go in with one set-based
  --     insert; naming them in their parents' child maps needs their ids up
  --     front, which is what node_hash_uuid computes.
  WITH split AS (
    SELECT
      wr.*,
      EXISTS (
        SELECT
          1
        FROM unnest(d_key) AS dr (node_key)
        WHERE dr.node_key = wr.node_key) AS is_dir
    FROM unnest(w_key, w_depth, w_name, w_parent, w_data, w_kids, w_ktree) AS wr (node_key, depth, name, parent, data, kids, ktree)
),
  staged AS (
    SELECT
      wr.name,
      wr.parent,
      wr.data,
      CASE WHEN jsonb_typeof(wr.kids) = 'array' THEN
        ARRAY (
          SELECT
            jsonb_array_elements_text(wr.kids))::uuid[]
      END AS kids,
      CASE WHEN jsonb_typeof(wr.ktree) = 'array' THEN
        ARRAY (
          SELECT
            jsonb_array_elements_text(wr.ktree))::text[]
      END AS ktree
    FROM split AS wr
    WHERE NOT wr.is_dir
),
  with_ids AS (
    SELECT
      s.name,
      s.parent,
      s.data,
      s.kids,
      s.ktree,
      object_store_private.node_hash_uuid (s.data, s.kids, s.ktree) AS node_id
    FROM staged AS s
),
  inserted AS (
  INSERT INTO object_store_public.object (scope_id, data, kids, ktree)
    SELECT
      insert_nodes_at_paths.s_id,
      d.data,
      d.kids,
      d.ktree
    FROM (
      SELECT DISTINCT ON (w.node_id)
        w.node_id,
        w.data,
        w.kids,
        w.ktree
      FROM with_ids AS w
      ORDER BY
        w.node_id) AS d
  ON CONFLICT (id, scope_id)
    DO UPDATE SET
      scope_id = EXCLUDED.scope_id
    RETURNING
      id
)
  SELECT
    la.parents,
    la.children,
    da.keys,
    da.datas,
    da.kids,
    da.ktree
  FROM (
    SELECT
      coalesce(array_agg(g.parent), '{}') AS parents,
      coalesce(array_agg(g.children), '{}') AS children
    FROM (
      SELECT
        w.parent,
        jsonb_object_agg(w.name, to_jsonb(w.node_id)) AS children
      FROM with_ids AS w
      GROUP BY
        w.parent) AS g) AS la,
    (
      SELECT
        coalesce(array_agg(wr.node_key), '{}') AS keys,
        coalesce(array_agg(wr.data), '{}') AS datas,
        coalesce(array_agg(wr.kids), '{}') AS kids,
        coalesce(array_agg(wr.ktree), '{}') AS ktree
      FROM split AS wr
      WHERE wr.is_dir) AS da INTO lp_parent,
    lp_children,
    dw_key,
    dw_data,
    dw_kids,
    dw_ktree;

  -- 4b. build every dirty directory level by level, deepest first. One level is
  --     one set-based insert: nothing at the same depth can be another's child,
  --     so a level's nodes are independent, and node_hash_uuid gives their ids
  --     without a row to read them back from.
  FOR cur_depth IN REVERSE max_depth..0 LOOP
    WITH level AS (
      SELECT
        dr.node_key,
        dr.name,
        dr.parent
      FROM unnest(d_key, d_depth, d_name, d_parent) AS dr (node_key, depth, name, parent)
      WHERE dr.depth = cur_depth
),
    dir_kids AS (
      SELECT
        pd.parent AS parent_key,
        jsonb_object_agg(pd.name, to_jsonb(pd.node_id)) AS children
      FROM unnest(pd_name, pd_parent, pd_id) AS pd (name, parent, node_id)
      GROUP BY
        pd.parent
),
    merged AS (
      SELECT
        l.node_key,
        l.name,
        l.parent,
        CASE WHEN wr.node_key IS NOT NULL THEN
          wr.data
        ELSE
          base_obj.data
        END AS data,
        CASE WHEN jsonb_typeof(wr.ktree) = 'array' THEN
          ARRAY (
            SELECT
              jsonb_array_elements_text(wr.ktree))::text[]
        END AS raw_ktree,
        CASE WHEN jsonb_typeof(wr.kids) = 'array' THEN
          ARRAY (
            SELECT
              jsonb_array_elements_text(wr.kids))::uuid[]
        END AS raw_kids,
        -- a write at this path replaces the directory's data and base children;
        -- otherwise the pre-existing node's children are the base to merge into
        (CASE WHEN wr.node_key IS NOT NULL THEN
          coalesce(object_store_utils.zip_arrays (
            CASE WHEN jsonb_typeof(wr.ktree) = 'array' THEN
              ARRAY (
                SELECT
                  jsonb_array_elements_text(wr.ktree))::text[]
            END,
            CASE WHEN jsonb_typeof(wr.kids) = 'array' THEN
              ARRAY (
                SELECT
                  jsonb_array_elements_text(wr.kids))::uuid[]
            END), '{}'::jsonb)
        ELSE
          coalesce(object_store_utils.zip_arrays (base_obj.ktree, base_obj.kids), '{}'::jsonb)
        END) || coalesce(lk.children, '{}'::jsonb) || coalesce(dk.children, '{}'::jsonb) AS children,
        -- a written path with no dirty child below it is a plain leaf write:
        -- keep its kids/ktree verbatim so empty arrays stay empty arrays and
        -- hash exactly as the singular path's direct insert does
        (wr.node_key IS NOT NULL
          AND lk.children IS NULL
          AND dk.children IS NULL) AS keep_raw_children
      FROM level AS l
      LEFT JOIN unnest(dw_key, dw_data, dw_kids, dw_ktree) AS wr (node_key, data, kids, ktree) ON wr.node_key = l.node_key
      LEFT JOIN unnest(lp_parent, lp_children) AS lk (parent_key, children) ON lk.parent_key = l.node_key
      LEFT JOIN dir_kids AS dk ON dk.parent_key = l.node_key
      LEFT JOIN unnest(b_key, b_id) AS bs (node_key, node_id) ON bs.node_key = l.node_key
      LEFT JOIN object_store_public.object AS base_obj ON base_obj.id = bs.node_id
        AND base_obj.scope_id = insert_nodes_at_paths.s_id
),
    built AS (
      SELECT
        m.name,
        m.parent,
        m.data,
        CASE WHEN m.keep_raw_children THEN
          m.raw_ktree
        ELSE
          u.ktree
        END AS ktree,
        CASE WHEN m.keep_raw_children THEN
          m.raw_kids
        ELSE
          u.kids
        END AS kids
      FROM merged AS m,
      LATERAL object_store_utils.unzip_obj_to_ktree_and_kids (m.children) AS u
),
    with_ids AS (
      SELECT
        b.name,
        b.parent,
        b.data,
        b.kids,
        b.ktree,
        object_store_private.node_hash_uuid (b.data, b.kids, b.ktree) AS node_id
      FROM built AS b
),
    inserted AS (
    INSERT INTO object_store_public.object (scope_id, data, kids, ktree)
      SELECT
        insert_nodes_at_paths.s_id,
        d.data,
        d.kids,
        d.ktree
      FROM (
        SELECT DISTINCT ON (w.node_id)
          w.node_id,
          w.data,
          w.kids,
          w.ktree
        FROM with_ids AS w
        ORDER BY
          w.node_id) AS d
    ON CONFLICT (id, scope_id)
      DO UPDATE SET
        scope_id = EXCLUDED.scope_id
      RETURNING
        id
)
    SELECT
      coalesce(array_agg(w.name), '{}'),
      coalesce(array_agg(w.parent), '{}'),
      coalesce(array_agg(w.node_id), '{}')
    FROM with_ids AS w INTO l_name,
      l_parent,
      l_id;
    pd_name := l_name;
    pd_parent := l_parent;
    pd_id := l_id;
  END LOOP;

  -- depth 0 is the root, and it is a single node: the last level built is it
  root_id := pd_id[1];
  RETURN root_id;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE SET jit TO off SET work_mem TO '64MB' SET plan_cache_mode TO force_custom_plan;