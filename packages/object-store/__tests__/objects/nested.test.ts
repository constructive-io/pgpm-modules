jest.setTimeout(30000);

import { getConnections, PgTestClient } from 'pgsql-test';

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
    // console.log(e);
  }
});

beforeEach(async () => {
  await pg.beforeEach();
});

afterEach(async () => {
  await pg.afterEach();
});

const insertNode = async ({
  root,
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
    [scope_id, root, path, data, kids, ktree]
  );
  return result.new_root;
};

const removeNode = async ({
  root,
  path
}: {
  root: string;
  path: string[];
}) => {
  const [result] = await pg.any(
    `SELECT object_store_public.remove_node_at_path(
      s_id := $1::uuid,
      root := $2::uuid,
      path := $3::text[]
    ) AS new_root`,
    [scope_id, root, path]
  );
  return result.new_root;
};

const freeze = async (rootId: string) => {
  await pg.any(
    `SELECT object_store_public.freeze_objects(
      s_id := $1::uuid,
      id := $2::uuid
    )`,
    [scope_id, rootId]
  );
};

const expectTree = async (rootId: string) => {
  const getAll = await pg.any(
    `SELECT * FROM object_store_public.get_all_objects_from_root(
      s_id := $1::uuid,
      id := $2::uuid
    )`,
    [scope_id, rootId]
  );
  return getAll.map((r: any) => {
    delete r.scope_id;
    delete r.created_at;
    return r;
  });
};

it('insert', async () => {
  const update1 = await insertNode({
    root: root.id,
    path: ['a', 'b'],
    data: {
      'hello there': 23
    }
  });

  const update2 = await insertNode({
    root: root.id,
    path: ['a', 'b'],
    data: {
      'hello there': 23
    }
  });
  expect(update1).toEqual(update2);
  await freeze(update1);
  expect(await expectTree(update1)).toMatchSnapshot();
});

it('remove', async () => {
  const update1 = await insertNode({
    root: root.id,
    path: ['a', 'b'],
    data: {
      'hello there': 23
    }
  });

  const update2 = await removeNode({
    root: update1,
    path: ['a', 'b']
  });
  expect(await expectTree(update2)).toMatchSnapshot();
});

