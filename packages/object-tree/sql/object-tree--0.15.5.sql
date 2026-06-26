\echo Use "CREATE EXTENSION object-tree" to load this file. \quit
CREATE SCHEMA object_tree_private;

GRANT USAGE ON SCHEMA object_tree_private TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_tree_private
  GRANT EXECUTE ON FUNCTIONS TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_tree_private
  GRANT ALL ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_tree_private
  GRANT ALL ON TABLES TO authenticated;

CREATE SCHEMA object_tree_public;

GRANT USAGE ON SCHEMA object_tree_public TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_tree_public
  GRANT EXECUTE ON FUNCTIONS TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_tree_public
  GRANT ALL ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA object_tree_public
  GRANT ALL ON TABLES TO authenticated;

CREATE TABLE object_tree_public.commit (
  id uuid NOT NULL DEFAULT uuidv7(),
  message text,
  scope_id uuid NOT NULL,
  store_id uuid NOT NULL,
  parent_ids uuid[],
  author_id uuid,
  committer_id uuid,
  tree_id uuid,
  date timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
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

CREATE FUNCTION object_tree_public.rev_parse(
  s_id uuid,
  store_id uuid,
  refname text DEFAULT 'main'
) RETURNS uuid AS $EOFCODE$
DECLARE
  tree_id uuid;
  commit_id uuid;
BEGIN

  SELECT r.commit_id FROM
    object_tree_public.ref r
      WHERE r.scope_id = s_id
      AND r.store_id = rev_parse.store_id
      AND r.name = refname
  INTO commit_id;

  IF (NOT FOUND) THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  SELECT c.tree_id FROM
    object_tree_public.commit c
      WHERE c.scope_id = s_id
      AND c.store_id = rev_parse.store_id
      AND c.id = commit_id
  INTO tree_id;

  IF (NOT FOUND) THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  RETURN tree_id;

END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION object_tree_public.get_object_at_path(
  s_id uuid,
  store_id uuid,
  path text[],
  refname text DEFAULT 'main'
) RETURNS object_store_public.object AS $EOFCODE$
DECLARE
  tree_id uuid;
  obj object_store_public.object;
BEGIN
    tree_id = object_tree_public.rev_parse(s_id, store_id, refname);
    SELECT * FROM object_store_public.get_node_at_path(s_id, tree_id, path)
  INTO obj;
  RETURN obj;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION object_tree_public.init_empty_repo(
  s_id uuid,
  store_id uuid
) RETURNS void AS $EOFCODE$
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

END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION object_tree_public.set_and_commit(
  s_id uuid,
  store_id uuid,
  refname text,
  path text[],
  data jsonb,
  kids uuid[],
  ktree text[]
) RETURNS uuid AS $EOFCODE$
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
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION object_tree_public.set_props_and_commit(
  s_id uuid,
  store_id uuid,
  refname text,
  path text[],
  data jsonb
) RETURNS uuid AS $EOFCODE$
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
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE UNIQUE INDEX idx_unique_object_ref_name ON object_tree_public.ref (store_id, (decode(md5(lower(name)), 'hex')));

CREATE TABLE object_tree_public.store (
  id uuid NOT NULL DEFAULT uuidv7(),
  name text NOT NULL,
  scope_id uuid NOT NULL,
  hash uuid,
  created_at timestamptz DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);

COMMENT ON TABLE object_tree_public.store IS 'A store represents an isolated object repository within a database.';

COMMENT ON COLUMN object_tree_public.store.id IS 'The primary unique identifier for the store.';

COMMENT ON COLUMN object_tree_public.store.name IS 'The name of the store (e.g., metaschema, migrations).';

COMMENT ON COLUMN object_tree_public.store.scope_id IS 'The scope this store belongs to.';

COMMENT ON COLUMN object_tree_public.store.hash IS 'The current head tree_id for this store.';

CREATE UNIQUE INDEX idx_unique_store_name ON object_tree_public.store (scope_id, (decode(md5(lower(name)), 'hex')));
