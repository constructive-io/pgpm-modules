-- Deploy schemas/object_store_public/procedures/insert_nodes_at_paths to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table
-- requires: schemas/object_store_private/procedures/node_hash_uuid
-- requires: schemas/object_store_utils/procedures/array_index_of
-- requires: schemas/object_store_utils/procedures/array_utils

BEGIN;

-- Batched write primitive: apply a whole set of writes in one bottom-up pass.
--
-- The store is content addressed, so writing a leaf cannot mutate its parent —
-- it mints a new parent, a new grandparent, and so on up to the root. Applying
-- N writes one at a time therefore costs N x depth node hashes and throws away
-- every root but the last. This pass hashes each dirty node exactly once:
--
--   1. stage the leaves (every write whose path is not also a directory),
--   2. derive every dirty ancestor directory,
--   3. resolve each dirty directory's existing node top-down from the current
--      root, so a dirty directory MERGES with the children it already has
--      instead of orphaning them,
--   4. build level by level from the deepest up.
--
-- Node ids are pure content hashes — no timestamps, no sequences, no insertion
-- order — so the root this returns is byte-identical to the one the eager
-- singular path produces for the same set of writes.
--
-- Paths are a jsonb array of path arrays; kids_list / ktree_list are optional
-- parallel jsonb arrays carrying each write's explicit children. Duplicate
-- paths within one batch are last-write-wins. A path that is also a prefix of
-- another path in the batch supplies that directory's data and base children
-- and the deeper writes merge on top — the result the eager path gives when the
-- shallower write is applied first.
--
-- The batch is carried in parallel arrays, unnested and joined, rather than in
-- keyed jsonb objects. Both are "one pass", but a per-row lookup into a
-- container holding the whole batch is not free: subscripting an N-element
-- jsonb[] walks it, so `datas[ord]` alone made the pass quadratic — 3.1s of a
-- 40k-path batch against 0.24s for the same values reached through
-- `unnest(datas) WITH ORDINALITY`. Directory children stay jsonb objects: that
-- is where the merge with a directory's existing children happens, the object's
-- key order is what fixes ktree/kids order and therefore the node hash, and
-- there are only ever as many directories as the tree is wide, not as many as
-- the batch is large.
CREATE FUNCTION object_store_public.insert_nodes_at_paths (s_id uuid, root uuid, paths jsonb, datas jsonb[], kids_list jsonb DEFAULT NULL, ktree_list jsonb DEFAULT NULL)
  RETURNS uuid
  AS $$
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
$$
LANGUAGE plpgsql
VOLATILE
-- Every query here is driven by unnested arrays, whose row counts the planner
-- cannot know: it costed one level of a 20k-path batch at 825,000 rows when the
-- level produced 79, and a cost that high turns JIT on. So each level paid
-- ~460ms compiling ~90 functions (Optimization 249ms, Emission 179ms) to
-- execute in single-digit milliseconds: 2.67s of JIT to do 0.32s of work, and
-- it recurs on every level of every call. The estimates are the defect and they
-- are not fixable from here, so decline the compiler rather than the plan.
SET jit = off
-- The same missing estimates also decide the hash sizes, so every level's
-- jsonb_object_agg and its joins batch against whatever work_mem happens to be.
-- At the 4MB default one level spills ~5MB: provisioning constructive wrote
-- 6,942,736 temp blocks (~53GB) across 10,366 level queries and the phase took
-- 1118s. Pinning work_mem here took it to 222s with the spill gone -- 5x, from
-- one setting, on the same box and commit. 64MB is where the spill reaches zero
-- for that batch shape; larger values measured no faster.
SET work_mem = '64MB'
-- And the estimates are only right while the plan is a custom one. unnest's
-- support function reads the array's real length from the Param, so the first
-- executions of a level plan it correctly -- but a plpgsql statement switches to
-- a generic plan on its third execution, and a generic plan has no Param to
-- read: the level comes out estimated at 1 row, which turns dir_kids into the
-- inner side of a nested loop and re-aggregates every directory of the level
-- below once per row of this one. Measured on a 20k-path batch, repeated in one
-- session: 5.7s, 6.2s, then 73s, 76s, 76s, ... -- and it only appears once the
-- table has statistics, so whether a run hits it depends on autovacuum, which
-- is where the ~55s-vs-437s bimodality in CI came from. Replanning each level
-- costs ~30% on the batches that were already fast and removes the 12x cliff.
SET plan_cache_mode = 'force_custom_plan';

COMMIT;
