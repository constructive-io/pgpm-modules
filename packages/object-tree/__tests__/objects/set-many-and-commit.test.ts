jest.setTimeout(60000);

import { getConnections, PgTestClient } from 'pgsql-test';

// One scope per repo: an empty root is a content hash like any other node, so
// two empty repos in one scope would collide on the primary key.
const eager_scope = 'd0f7ab73-356f-4aac-b9cb-d1a4274906d6';
const batched_scope = '7c2f8a10-4d3b-4a5e-9c11-2f6b8d0a4e77';

let pg: PgTestClient;
let teardown: () => Promise<void>;

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

interface Entry {
  path: string[];
  data: any;
}

const initRepo = async (scope_id: string, store_id: string) => {
  await pg.any(
    `SELECT object_tree_public.init_empty_repo(
      s_id := $1::uuid, store_id := $2::uuid
    )`,
    [scope_id, store_id]
  );
};

const setAndCommit = async (scope_id: string, store_id: string, entry: Entry) => {
  const [row] = await pg.any(
    `SELECT (object_tree_public.set_and_commit(
      s_id := $1::uuid,
      store_id := $2::uuid,
      refname := 'main',
      path := $3::text[],
      data := $4::jsonb,
      kids := '{}'::uuid[],
      ktree := '{}'::text[]
    )).tree_id AS tree_id`,
    [scope_id, store_id, entry.path, entry.data]
  );
  return row.tree_id as string;
};

const setManyAndCommit = async (scope_id: string, store_id: string, entries: Entry[]) => {
  const [row] = await pg.any(
    `SELECT (object_tree_public.set_many_and_commit(
      s_id := $1::uuid,
      store_id := $2::uuid,
      refname := 'main',
      entries := $3::jsonb
    )).tree_id AS tree_id`,
    [
      scope_id,
      store_id,
      JSON.stringify(
        entries.map((e) => ({ path: e.path, data: e.data, kids: [] as string[], ktree: [] as string[] }))
      )
    ]
  );
  return row.tree_id as string;
};

const countCommits = async (scope_id: string, store_id: string) => {
  const [row] = await pg.any(
    `SELECT count(*)::int AS n FROM object_tree_public.commit
      WHERE scope_id = $1 AND store_id = $2`,
    [scope_id, store_id]
  );
  return row.n as number;
};

const getObject = async (scope_id: string, store_id: string, path: string[]) => {
  const [row] = await pg.any(
    `SELECT * FROM object_tree_public.get_object_at_path(
      s_id := $1::uuid, store_id := $2::uuid, path := $3::text[], refname := 'main'
    )`,
    [scope_id, store_id, path]
  );
  return row;
};

const entries: Entry[] = [
  { path: ['sql', 'deploy', 'a.sql'], data: { body: 'a' } },
  { path: ['sql', 'deploy', 'b.sql'], data: { body: 'b' } },
  { path: ['sql', 'revert', 'a.sql'], data: { body: 'revert a' } },
  { path: ['package.json'], data: { name: 'pkg' } }
];

describe('set_many_and_commit', () => {
  it('one call is one commit and matches writing the entries one at a time', async () => {
    const eager_store = '11111111-1111-4111-8111-111111111111';
    const batched_store = '22222222-2222-4222-8222-222222222222';
    await initRepo(eager_scope, eager_store);
    await initRepo(batched_scope, batched_store);

    let eager_tree = '';
    for (const entry of entries) {
      eager_tree = await setAndCommit(eager_scope, eager_store, entry);
    }
    const batched_tree = await setManyAndCommit(batched_scope, batched_store, entries);

    expect(batched_tree).toEqual(eager_tree);
    expect(await countCommits(eager_scope, eager_store)).toEqual(1 + entries.length);
    expect(await countCommits(batched_scope, batched_store)).toEqual(2);
    expect((await getObject(batched_scope, batched_store, ['sql', 'deploy', 'b.sql'])).data).toEqual({
      body: 'b'
    });
  });

  it('a second batch merges with what the first batch wrote', async () => {
    const store_id = '33333333-3333-4333-8333-333333333333';
    await initRepo(batched_scope, store_id);
    await setManyAndCommit(batched_scope, store_id, entries);
    await setManyAndCommit(batched_scope, store_id, [
      { path: ['sql', 'deploy', 'c.sql'], data: { body: 'c' } }
    ]);

    expect((await getObject(batched_scope, store_id, ['sql', 'deploy', 'a.sql'])).data).toEqual({
      body: 'a'
    });
    expect((await getObject(batched_scope, store_id, ['sql', 'deploy', 'c.sql'])).data).toEqual({
      body: 'c'
    });
    expect(await countCommits(batched_scope, store_id)).toEqual(3);
  });

  it('nothing to write leaves the ref alone', async () => {
    const store_id = '44444444-4444-4444-8444-444444444444';
    await initRepo(batched_scope, store_id);
    const tree_id = await setManyAndCommit(batched_scope, store_id, entries);
    expect(await setManyAndCommit(batched_scope, store_id, [])).toEqual(tree_id);
    expect(await countCommits(batched_scope, store_id)).toEqual(2);
  });
});
