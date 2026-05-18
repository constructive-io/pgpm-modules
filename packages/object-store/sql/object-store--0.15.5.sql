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

CREATE FUNCTION object_store_utils.array_get_last(arr anyarray) RETURNS anyelement AS $EOFCODE$
  SELECT arr[array_length(arr, 1)];
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION object_store_utils.array_index_of(arr anyarray, el anyelement) RETURNS int AS $EOFCODE$ 
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

CREATE FUNCTION object_store_utils.array_pop(srcarr anyarray) RETURNS SETOF anyarray AS $EOFCODE$ 
SELECT ARRAY (
 SELECT UNNEST(srcarr) LIMIT (
  SELECT array_upper(srcarr, 1) - 1
 )
)
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION object_store_utils.array_shift(srcarr anyarray) RETURNS SETOF anyarray AS $EOFCODE$ 
SELECT srcarr[2:array_length(srcarr, 1)]
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION object_store_utils.zip_arrays(a text[], b anyarray) RETURNS jsonb AS $EOFCODE$
DECLARE
  obj jsonb = '{}'::jsonb;
  i int;
BEGIN
	IF (cardinality(a) != cardinality(b)) THEN 
		RAISE EXCEPTION 'cannot zip arrays of different cardinality';
	END IF;
	
	FOR i IN
	SELECT * FROM generate_series(1, cardinality(a))
	LOOP
		obj = jsonb_set(obj, ARRAY[a[i]]::text[], to_jsonb( (b[i]::text) ) );
	END LOOP;
	RETURN obj;
END;
$EOFCODE$ LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION object_store_utils.unzip_obj_to_ktree_and_kids(obj jsonb) RETURNS TABLE ( ktree text[], kids uuid[] ) AS $EOFCODE$
DECLARE
  key text;
  value text;
BEGIN
	FOR key, value IN 
	SELECT * FROM jsonb_each_text(obj)
	LOOP
		ktree = array_append(ktree, key);
  	kids = array_append(kids, value::uuid);
	END LOOP;
	
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

CREATE FUNCTION object_store_public.get_all_objects_from_root(s_id uuid, id uuid) RETURNS SETOF object_store_public.object AS $EOFCODE$ WITH RECURSIVE hierarchy AS (
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

CREATE FUNCTION object_store_public.get_all(s_id uuid, id uuid) RETURNS TABLE ( path text[], data jsonb ) AS $EOFCODE$ 
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

CREATE FUNCTION object_store_public.get_node_at_path(s_id uuid, id uuid, path text[] DEFAULT CAST(ARRAY[] AS text[])) RETURNS object_store_public.object AS $EOFCODE$ 

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

CREATE FUNCTION object_store_public.get_path_objects_from_root(s_id uuid, id uuid, path text[] DEFAULT CAST(ARRAY[] AS text[])) RETURNS SETOF object_store_public.object AS $EOFCODE$ 

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

CREATE FUNCTION object_store_public.insert_node_at_path(s_id uuid, root uuid, path text[], data jsonb, kids uuid[], ktree text[]) RETURNS uuid AS $EOFCODE$
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
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION object_store_public.object_hash_uuid(obj object_store_public.object) RETURNS uuid AS $EOFCODE$
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

CREATE FUNCTION object_store_public.remove_node_at_path(s_id uuid, root uuid, path text[]) RETURNS uuid AS $EOFCODE$
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

CREATE FUNCTION object_store_public.update_node_at_path(s_id uuid, root uuid, path text[], data jsonb, kids uuid[], ktree text[]) RETURNS uuid AS $EOFCODE$
BEGIN
  RETURN object_store_public.insert_node_at_path(s_id, root, path, data, kids, ktree);
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION object_store_public.set_data_at_path(s_id uuid, root uuid, path text[], data jsonb) RETURNS uuid AS $EOFCODE$
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

CREATE FUNCTION object_store_public.freeze_objects(s_id uuid, id uuid) RETURNS void AS $EOFCODE$
BEGIN

WITH RECURSIVE hierarchy AS (
    SELECT
        *
    FROM
        object_store_public.object o
    WHERE
        o.id = freeze_objects.id AND o.scope_id=s_id
    UNION
    SELECT
        object.*
    FROM
        object_store_public.object AS object
        JOIN hierarchy a ON (object.id = ANY (a.kids) AND object.scope_id=a.scope_id))

UPDATE object_store_public.object o
  SET frzn = TRUE
FROM hierarchy
  WHERE hierarchy.id = o.id;

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
