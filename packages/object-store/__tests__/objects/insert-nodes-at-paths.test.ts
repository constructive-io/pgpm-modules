jest.setTimeout(60000);

import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

// One scope per tree: an empty root is a content hash like any other node, so
// two empty trees in one scope would collide on the primary key.
const eager_scope = '2b8b6d4c-8b8c-4a0a-9b9d-1d0a3f6a1c21';
const batched_scope = '9a1c0f52-3f2e-4a77-8a2c-6f7c1b0d5e34';

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());
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

interface Write {
  path: string[];
  data: any;
}

const newRoot = async (scope_id: string) => {
  const [row] = await pg.any(
    `INSERT INTO object_store_public.object (scope_id) VALUES ($1) RETURNING id`,
    [scope_id]
  );
  return row.id as string;
};

const insertNode = async (scope_id: string, rootId: string, { path, data }: Write) => {
  const [row] = await pg.any(
    `SELECT object_store_public.insert_node_at_path(
      s_id := $1::uuid,
      root := $2::uuid,
      path := $3::text[],
      data := $4::jsonb,
      kids := '{}'::uuid[],
      ktree := '{}'::text[]
    ) AS new_root`,
    [scope_id, rootId, path, data]
  );
  return row.new_root as string;
};

const insertNodes = async (scope_id: string, rootId: string, writes: Write[]) => {
  const [row] = await pg.any(
    `SELECT object_store_public.insert_nodes_at_paths(
      s_id := $1::uuid,
      root := $2::uuid,
      paths := $3::jsonb,
      datas := $4::jsonb[],
      kids_list := $5::jsonb,
      ktree_list := $6::jsonb
    ) AS new_root`,
    [
      scope_id,
      rootId,
      JSON.stringify(writes.map((w) => w.path)),
      writes.map((w) => JSON.stringify(w.data)),
      JSON.stringify(writes.map((): string[] => [])),
      JSON.stringify(writes.map((): string[] => []))
    ]
  );
  return row.new_root as string;
};

// The batch with kids/ktree left to the caller: `null` means "no children
// given", an empty array means "given, and empty", and the two hash differently.
const insertNodesRaw = async (
  scope_id: string,
  rootId: string,
  paths: string[][],
  datas: any[],
  kids_list: (string[] | null)[] | null,
  ktree_list: (string[] | null)[] | null
) => {
  const [row] = await pg.any(
    `SELECT object_store_public.insert_nodes_at_paths(
      s_id := $1::uuid,
      root := $2::uuid,
      paths := $3::jsonb,
      datas := $4::jsonb[],
      kids_list := $5::jsonb,
      ktree_list := $6::jsonb
    ) AS new_root`,
    [
      scope_id,
      rootId,
      JSON.stringify(paths),
      datas.map((d) => JSON.stringify(d)),
      kids_list === null ? null : JSON.stringify(kids_list),
      ktree_list === null ? null : JSON.stringify(ktree_list)
    ]
  );
  return row.new_root as string;
};

const eagerly = async (scope_id: string, rootId: string, writes: Write[]) => {
  let current = rootId;
  for (const write of writes) {
    current = await insertNode(scope_id, current, write);
  }
  return current;
};

const getNode = async (rootId: string, path: string[], scope_id = batched_scope) => {
  const [row] = await pg.any(
    `SELECT * FROM object_store_public.get_node_at_path(
      s_id := $1::uuid, id := $2::uuid, path := $3::text[]
    )`,
    [scope_id, rootId, path]
  );
  return row;
};

// The same writes applied one at a time and applied as one batch must produce
// the identical root: node ids are pure content hashes, with no timestamp,
// sequence or insertion order in them.
const expectSameRoot = async (writes: Write[], seed: Write[] = []) => {
  const eagerRoot = await eagerly(
    eager_scope,
    await eagerly(eager_scope, await newRoot(eager_scope), seed),
    writes
  );
  const batchedRoot = await insertNodes(
    batched_scope,
    await eagerly(batched_scope, await newRoot(batched_scope), seed),
    writes
  );
  expect(batchedRoot).toEqual(eagerRoot);
  return batchedRoot;
};

describe('insert_nodes_at_paths equivalence with the eager path', () => {
  it('single write', async () => {
    await expectSameRoot([{ path: ['a', 'b', 'c'], data: { v: 1 } }]);
  });

  it('write at the root itself', async () => {
    await expectSameRoot([{ path: [], data: { v: 'root' } }]);
  });

  it('deeply nested path', async () => {
    await expectSameRoot([
      { path: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'], data: { deep: true } }
    ]);
  });

  it('duplicate paths in one batch: last write wins', async () => {
    const root = await expectSameRoot([
      { path: ['x', 'y'], data: { v: 1 } },
      { path: ['x', 'y'], data: { v: 2 } },
      { path: ['x', 'y'], data: { v: 3 } }
    ]);
    expect((await getNode(root, ['x', 'y'])).data).toEqual({ v: 3 });
  });

  it('a write whose path is a prefix of another write in the same batch', async () => {
    const root = await expectSameRoot([
      { path: ['dir'], data: { on: 'dir' } },
      { path: ['dir', 'leaf'], data: { on: 'leaf' } }
    ]);
    expect((await getNode(root, ['dir'])).data).toEqual({ on: 'dir' });
    expect((await getNode(root, ['dir', 'leaf'])).data).toEqual({
      on: 'leaf'
    });
  });

  it('merging into a directory that already has children keeps them', async () => {
    const seed: Write[] = [
      { path: ['dir', 'old1'], data: { o: 1 } },
      { path: ['dir', 'old2'], data: { o: 2 } },
      { path: ['other', 'keep'], data: { k: 1 } }
    ];
    const root = await expectSameRoot(
      [
        { path: ['dir', 'new1'], data: { n: 1 } },
        { path: ['dir', 'new2'], data: { n: 2 } }
      ],
      seed
    );

    const dir = await getNode(root, ['dir']);
    expect(dir.ktree.sort()).toEqual(['new1', 'new2', 'old1', 'old2']);
    expect((await getNode(root, ['dir', 'old1'])).data).toEqual({ o: 1 });
    expect((await getNode(root, ['other', 'keep'])).data).toEqual({ k: 1 });
  });

  it('overwriting an existing leaf', async () => {
    const root = await expectSameRoot([{ path: ['dir', 'leaf'], data: { v: 2 } }], [
      { path: ['dir', 'leaf'], data: { v: 1 } },
      { path: ['dir', 'sibling'], data: { v: 9 } }
    ]);
    expect((await getNode(root, ['dir', 'leaf'])).data).toEqual({ v: 2 });
    expect((await getNode(root, ['dir', 'sibling'])).data).toEqual({ v: 9 });
  });

  it('200 changes / 800 paths produce the identical root', async () => {
    const writes: Write[] = [];
    for (let i = 1; i <= 200; i++) {
      for (const part of ['deploy', 'revert', 'verify', 'meta']) {
        writes.push({
          path: ['sql', 'deploy', `change_${i}`, part],
          data: { i, part }
        });
      }
    }
    await expectSameRoot(writes);
  });

  it('omitted kids/ktree are not the same node as empty ones', async () => {
    const path = [['a', 'leaf']];
    const data = [{ v: 1 }];

    const omitted = await insertNodesRaw(
      batched_scope,
      await newRoot(batched_scope),
      path,
      data,
      null,
      null
    );
    const empty = await insertNodesRaw(
      eager_scope,
      await newRoot(eager_scope),
      path,
      data,
      [[]],
      [[]]
    );

    expect(omitted).not.toEqual(empty);
    expect((await getNode(omitted, ['a', 'leaf'])).ktree).toBeNull();
    expect((await getNode(empty, ['a', 'leaf'], eager_scope)).ktree).toEqual([]);
  });

  it('explicit kids/ktree on a write are stored as given', async () => {
    const seeded = await insertNodes(batched_scope, await newRoot(batched_scope), [
      { path: ['target'], data: { t: 1 } }
    ]);
    const target = (await getNode(seeded, ['target'])).id as string;

    const root = await insertNodesRaw(
      batched_scope,
      seeded,
      [['dir', 'linker']],
      [{ v: 'links' }],
      [[target]],
      [['alias']]
    );

    const linker = await getNode(root, ['dir', 'linker']);
    expect(linker.ktree).toEqual(['alias']);
    expect(linker.kids).toEqual([target]);
    expect((await getNode(root, ['dir', 'linker', 'alias'])).data).toEqual({ t: 1 });
  });

  it('empty input returns the root unchanged', async () => {
    const root = await newRoot(batched_scope);
    expect(await insertNodes(batched_scope, root, [])).toEqual(root);
  });
});
