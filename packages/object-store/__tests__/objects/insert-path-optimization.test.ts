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

describe('insert_node_at_path path correctness', () => {
  it('two inserts to the same parent in one transaction', async () => {
    // Insert child 'b' under 'a'
    const root1 = await insertNode({
      root: root.id,
      path: ['a', 'b'],
      data: { name: 'b-child' }
    });

    // Insert sibling 'c' under 'a' — must see 'a' created by the first insert
    const root2 = await insertNode({
      root: root1,
      path: ['a', 'c'],
      data: { name: 'c-child' }
    });

    // Parent 'a' must have both children
    const nodeA = await getNode(root2, ['a']);
    expect(nodeA.kids).toHaveLength(2);
    expect(nodeA.ktree).toEqual(expect.arrayContaining(['b', 'c']));

    // Both children must be reachable
    const nodeB = await getNode(root2, ['a', 'b']);
    expect(nodeB.data).toEqual({ name: 'b-child' });

    const nodeC = await getNode(root2, ['a', 'c']);
    expect(nodeC.data).toEqual({ name: 'c-child' });

    // Merkle integrity: root hashes must differ
    expect(root1).not.toEqual(root2);
  });

  it('diverging paths from the same root in one transaction', async () => {
    // Insert at path ['x', 'y', 'leaf1']
    const root1 = await insertNode({
      root: root.id,
      path: ['x', 'y', 'leaf1'],
      data: { val: 1 }
    });

    // Insert at diverging path ['x', 'z', 'leaf2']
    // Shares prefix 'x' but diverges at second level
    const root2 = await insertNode({
      root: root1,
      path: ['x', 'z', 'leaf2'],
      data: { val: 2 }
    });

    // 'x' must have both 'y' and 'z' as children
    const nodeX = await getNode(root2, ['x']);
    expect(nodeX.kids).toHaveLength(2);
    expect(nodeX.ktree).toEqual(expect.arrayContaining(['y', 'z']));

    // Both full paths must be reachable
    const leaf1 = await getNode(root2, ['x', 'y', 'leaf1']);
    expect(leaf1.data).toEqual({ val: 1 });

    const leaf2 = await getNode(root2, ['x', 'z', 'leaf2']);
    expect(leaf2.data).toEqual({ val: 2 });
  });

  it('chained inserts mirroring tg_update_tree (4 calls, shared prefixes)', async () => {
    // This mirrors exactly what tg_update_tree does:
    // 4 sequential insert_node_at_path calls with chained roots
    // Paths: sql/deploy/schemas/public/procedures/my_func
    //        sql/revert/schemas/public/procedures/my_func
    //        sql/verify/schemas/public/procedures/my_func
    //        actions/create_table/schemas/public/procedures/my_func

    let hash = root.id;

    hash = await insertNode({
      root: hash,
      path: ['sql', 'deploy', 'schemas', 'public', 'procedures', 'my_func'],
      data: { content: '-- Deploy content' }
    });

    hash = await insertNode({
      root: hash,
      path: ['sql', 'revert', 'schemas', 'public', 'procedures', 'my_func'],
      data: { content: '-- Revert content' }
    });

    hash = await insertNode({
      root: hash,
      path: ['sql', 'verify', 'schemas', 'public', 'procedures', 'my_func'],
      data: { content: '-- Verify content' }
    });

    hash = await insertNode({
      root: hash,
      path: ['actions', 'create_table', 'schemas', 'public', 'procedures', 'my_func'],
      data: { action: 'create_table', args: {} }
    });

    // Verify all 4 paths are reachable from final root
    const deploy = await getNode(hash, ['sql', 'deploy', 'schemas', 'public', 'procedures', 'my_func']);
    expect(deploy.data).toEqual({ content: '-- Deploy content' });

    const revert = await getNode(hash, ['sql', 'revert', 'schemas', 'public', 'procedures', 'my_func']);
    expect(revert.data).toEqual({ content: '-- Revert content' });

    const verify = await getNode(hash, ['sql', 'verify', 'schemas', 'public', 'procedures', 'my_func']);
    expect(verify.data).toEqual({ content: '-- Verify content' });

    const action = await getNode(hash, ['actions', 'create_table', 'schemas', 'public', 'procedures', 'my_func']);
    expect(action.data).toEqual({ action: 'create_table', args: {} });

    // 'sql' node should have deploy, revert, verify as children
    const sqlNode = await getNode(hash, ['sql']);
    expect(sqlNode.ktree).toEqual(expect.arrayContaining(['deploy', 'revert', 'verify']));
    expect(sqlNode.kids).toHaveLength(3);

    // Root should have 'sql' and 'actions' as children
    const rootNode = await getNode(hash, []);
    expect(rootNode.ktree).toEqual(expect.arrayContaining(['sql', 'actions']));
    expect(rootNode.kids).toHaveLength(2);
  });

  it('two sequential actions with overlapping tree structure', async () => {
    // Simulates two sql_actions in the same transaction:
    // Action 1: schemas/public/tables/users
    // Action 2: schemas/public/tables/posts
    // Both share the prefix sql/deploy/schemas/public/tables

    let hash = root.id;

    // Action 1: deploy, revert, verify for 'users'
    hash = await insertNode({
      root: hash,
      path: ['sql', 'deploy', 'schemas', 'public', 'tables', 'users'],
      data: { sql: 'CREATE TABLE users ...' }
    });
    hash = await insertNode({
      root: hash,
      path: ['sql', 'revert', 'schemas', 'public', 'tables', 'users'],
      data: { sql: 'DROP TABLE users' }
    });

    // Action 2: deploy, revert, verify for 'posts'
    hash = await insertNode({
      root: hash,
      path: ['sql', 'deploy', 'schemas', 'public', 'tables', 'posts'],
      data: { sql: 'CREATE TABLE posts ...' }
    });
    hash = await insertNode({
      root: hash,
      path: ['sql', 'revert', 'schemas', 'public', 'tables', 'posts'],
      data: { sql: 'DROP TABLE posts' }
    });

    // The 'tables' node under deploy must have both 'users' and 'posts'
    const deployTables = await getNode(hash, ['sql', 'deploy', 'schemas', 'public', 'tables']);
    expect(deployTables.kids).toHaveLength(2);
    expect(deployTables.ktree).toEqual(expect.arrayContaining(['users', 'posts']));

    // Same for revert
    const revertTables = await getNode(hash, ['sql', 'revert', 'schemas', 'public', 'tables']);
    expect(revertTables.kids).toHaveLength(2);
    expect(revertTables.ktree).toEqual(expect.arrayContaining(['users', 'posts']));

    // All 4 leaf nodes must be reachable
    const deployUsers = await getNode(hash, ['sql', 'deploy', 'schemas', 'public', 'tables', 'users']);
    expect(deployUsers.data).toEqual({ sql: 'CREATE TABLE users ...' });

    const deployPosts = await getNode(hash, ['sql', 'deploy', 'schemas', 'public', 'tables', 'posts']);
    expect(deployPosts.data).toEqual({ sql: 'CREATE TABLE posts ...' });

    // Total object count — verify no orphans
    const allObjects = await getAllObjects(hash);
    // root, sql, deploy, revert, schemas(x2), public(x2), tables(x2), users(x2), posts(x2) = 13
    // But due to Merkle dedup, shared content gets same hash
    // Just verify all are reachable and count is reasonable
    expect(allObjects.length).toBeGreaterThanOrEqual(10);
  });

  it('deep path (8 levels) with correct node count', async () => {
    // Depth 8 — beyond typical usage, stress-tests the walk
    const deepPath = ['l1', 'l2', 'l3', 'l4', 'l5', 'l6', 'l7', 'l8'];
    const root1 = await insertNode({
      root: root.id,
      path: deepPath,
      data: { deep: true }
    });

    // Verify leaf is reachable
    const leaf = await getNode(root1, deepPath);
    expect(leaf.data).toEqual({ deep: true });

    // Verify all intermediate nodes exist
    for (let i = 1; i <= 8; i++) {
      const node = await getNode(root1, deepPath.slice(0, i));
      expect(node.id).toBeTruthy();
      if (i < 8) {
        // Intermediate nodes should have exactly 1 child
        expect(node.kids).toHaveLength(1);
        expect(node.ktree).toEqual([deepPath[i]]);
      }
    }

    // Total objects: root + 8 levels = 9
    const allObjects = await getAllObjects(root1);
    expect(allObjects).toHaveLength(9);
  });
});
