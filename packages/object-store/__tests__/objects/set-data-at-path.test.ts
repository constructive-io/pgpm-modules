jest.setTimeout(30000);

import { getConnections, PgTestClient } from 'constructive-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;
let root: any;

const scope_id = 'd0f7ab73-356f-4aac-b9cb-d1a4274906d6';

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());

  const [rootResult] = await pg.any(
    `INSERT INTO object_store_public.object (scope_id)
     VALUES ($1)
     RETURNING *`,
    [scope_id]
  );
  root = rootResult;
});

afterAll(async () => {
  try {
    await teardown();
  } catch (e) {
    // ignore
  }
});

beforeEach(async () => {
  await pg.beforeEach();
});

afterEach(async () => {
  await pg.afterEach();
});

const insertNode = async ({
  root: rootId,
  path,
  data,
  kids = [],
  ktree = []
}: {
  root: string;
  path: string[];
  data: any;
  kids?: string[];
  ktree?: string[];
}) => {
  const [result] = await pg.any(
    `SELECT object_store_public.insert_node_at_path(
      s_id := $1::uuid,
      root := $2::uuid,
      path := $3::text[],
      data := $4::jsonb,
      kids := $5::uuid[],
      ktree := $6::text[]
    ) AS new_root`,
    [scope_id, rootId, path, data, kids, ktree]
  );
  return result.new_root;
};

const setData = async ({
  root: rootId,
  path,
  data
}: {
  root: string;
  path: string[];
  data: any;
}) => {
  const [result] = await pg.any(
    `SELECT object_store_public.set_data_at_path(
      s_id := $1::uuid,
      root := $2::uuid,
      path := $3::text[],
      data := $4::jsonb
    ) AS new_root`,
    [scope_id, rootId, path, data]
  );
  return result.new_root;
};

const getNode = async (rootId: string, path: string[]) => {
  const [result] = await pg.any(
    `SELECT * FROM object_store_public.get_node_at_path(
      s_id := $1::uuid,
      id := $2::uuid,
      path := $3::text[]
    )`,
    [scope_id, rootId, path]
  );
  return result;
};

const getAllObjects = async (rootId: string) => {
  return pg.any(
    `SELECT * FROM object_store_public.get_all_objects_from_root(
      s_id := $1::uuid,
      id := $2::uuid
    )`,
    [scope_id, rootId]
  );
};

describe('set_data_at_path', () => {
  it('preserves children when updating data', async () => {
    // Build a tree: root -> a -> b (leaf with data)
    const root1 = await insertNode({
      root: root.id,
      path: ['a', 'b'],
      data: { name: 'leaf' }
    });

    // Add a sibling: root -> a -> c
    const root2 = await insertNode({
      root: root1,
      path: ['a', 'c'],
      data: { name: 'sibling' }
    });

    // Get node 'a' — it should have kids [b, c]
    const nodeA_before = await getNode(root2, ['a']);
    expect(nodeA_before.kids).toHaveLength(2);
    expect(nodeA_before.ktree).toEqual(expect.arrayContaining(['b', 'c']));

    // set_data_at_path on 'a' — change only data, children must survive
    const root3 = await setData({
      root: root2,
      path: ['a'],
      data: { name: 'updated-a', extra: true }
    });

    // Verify children are preserved
    const nodeA_after = await getNode(root3, ['a']);
    expect(nodeA_after.data).toEqual({ name: 'updated-a', extra: true });
    expect(nodeA_after.kids).toHaveLength(2);
    expect(nodeA_after.ktree).toEqual(nodeA_before.ktree);

    // Verify leaf nodes are still reachable
    const leafB = await getNode(root3, ['a', 'b']);
    expect(leafB.data).toEqual({ name: 'leaf' });

    const leafC = await getNode(root3, ['a', 'c']);
    expect(leafC.data).toEqual({ name: 'sibling' });
  });

  it('returns a new root hash when data changes (Merkle cascade)', async () => {
    const root1 = await insertNode({
      root: root.id,
      path: ['x', 'y'],
      data: { version: 1 }
    });

    const root2 = await setData({
      root: root1,
      path: ['x', 'y'],
      data: { version: 2 }
    });

    // Different data => different Merkle hash => different root
    expect(root2).not.toEqual(root1);

    // Verify the leaf data actually changed
    const leaf = await getNode(root2, ['x', 'y']);
    expect(leaf.data).toEqual({ version: 2 });
  });

  it('returns the same root hash for identical data (content-addressable)', async () => {
    const root1 = await insertNode({
      root: root.id,
      path: ['p'],
      data: { value: 42 }
    });

    // set_data_at_path with the same data should produce the same hash
    const root2 = await setData({
      root: root1,
      path: ['p'],
      data: { value: 42 }
    });

    expect(root2).toEqual(root1);
  });

  it('creates a new node when path does not exist', async () => {
    const root1 = await setData({
      root: root.id,
      path: ['new', 'node'],
      data: { created: true }
    });

    const node = await getNode(root1, ['new', 'node']);
    expect(node.data).toEqual({ created: true });
    // set_data_at_path initializes kids/ktree as empty arrays (not NULL)
    // because the DECLARE defaults are ARRAY[]::uuid[] and ARRAY[]::text[]
    expect(node.kids).toEqual([]);
    expect(node.ktree).toEqual([]);
  });

  it('preserves full tree integrity across multiple set_data_at_path calls', async () => {
    // Build a deeper tree
    let currentRoot = root.id;
    currentRoot = await insertNode({
      root: currentRoot,
      path: ['docs', 'readme'],
      data: { content: '# README' }
    });
    currentRoot = await insertNode({
      root: currentRoot,
      path: ['docs', 'contributing'],
      data: { content: '# Contributing' }
    });
    currentRoot = await insertNode({
      root: currentRoot,
      path: ['src', 'index'],
      data: { content: 'export default {}' }
    });

    const objectsBefore = await getAllObjects(currentRoot);

    // Update only the readme data
    const updatedRoot = await setData({
      root: currentRoot,
      path: ['docs', 'readme'],
      data: { content: '# README v2' }
    });

    const objectsAfter = await getAllObjects(updatedRoot);

    // Tree should have the same number of nodes (no orphans, no duplicates)
    expect(objectsAfter).toHaveLength(objectsBefore.length);

    // Unchanged nodes should still be reachable with correct data
    const contributing = await getNode(updatedRoot, ['docs', 'contributing']);
    expect(contributing.data).toEqual({ content: '# Contributing' });

    const index = await getNode(updatedRoot, ['src', 'index']);
    expect(index.data).toEqual({ content: 'export default {}' });

    // Updated node should have new data
    const readme = await getNode(updatedRoot, ['docs', 'readme']);
    expect(readme.data).toEqual({ content: '# README v2' });
  });
});

describe('CHECK constraint on kids/ktree arrays', () => {
  it('rejects mismatched kids and ktree arrays', async () => {
    // The object_hash_uuid BEFORE trigger fires before the CHECK constraint
    // and raises "mismatched array dimensions" when computing the hash.
    // The CHECK constraint is a belt-and-suspenders safeguard.
    await expect(
      pg.any(
        `INSERT INTO object_store_public.object (scope_id, data, kids, ktree)
         VALUES ($1, $2, $3::uuid[], $4::text[])`,
        [
          scope_id,
          { test: true },
          ['d0f7ab73-356f-4aac-b9cb-d1a4274906d6'],
          ['a', 'b'] // 1 kid, 2 ktree entries — mismatch
        ]
      )
    ).rejects.toThrow(/mismatched array dimensions/);
  });

  it('allows matching kids and ktree arrays', async () => {
    const [result] = await pg.any(
      `INSERT INTO object_store_public.object (scope_id, data, kids, ktree)
       VALUES ($1, $2, $3::uuid[], $4::text[])
       RETURNING *`,
      [
        scope_id,
        { test: true },
        ['d0f7ab73-356f-4aac-b9cb-d1a4274906d6'],
        ['a']
      ]
    );
    expect(result.kids).toHaveLength(1);
    expect(result.ktree).toHaveLength(1);
  });

  it('allows both kids and ktree to be NULL', async () => {
    const [result] = await pg.any(
      `INSERT INTO object_store_public.object (scope_id, data)
       VALUES ($1, $2)
       RETURNING *`,
      [scope_id, { leaf: true }]
    );
    expect(result.kids).toBeNull();
    expect(result.ktree).toBeNull();
  });
});
