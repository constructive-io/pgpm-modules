jest.setTimeout(30000);

import { getConnections, PgTestClient } from 'constructive-test';
import { snapshot } from 'pgsql-test/utils';

const scope_id = 'd0f7ab73-356f-4aac-b9cb-d1a4274906d6';
const store_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
let pg: PgTestClient;
let teardown: () => Promise<void>;

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());
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

const insertNode = async (path: string[], data: any) => {
  return await pg.any(
    `SELECT * FROM object_tree_public.set_and_commit(
      s_id := $1::uuid,
      store_id := $2::uuid,
      refname := $3::text,
      path := $4::text[],
      data := $5::jsonb,
      kids := $6::uuid[],
      ktree := $7::text[]
    )`,
    [scope_id, store_id, 'main', path, data, [], []]
  );
};

const setProps = async (path: string[], data: any) => {
  return await pg.any(
    `SELECT * FROM object_tree_public.set_props_and_commit(
      s_id := $1::uuid,
      store_id := $2::uuid,
      refname := $3::text,
      path := $4::text[],
      data := $5::jsonb
    )`,
    [scope_id, store_id, 'main', path, data]
  );
};

it('create a page', async () => {
  await pg.any(`SELECT * FROM object_tree_public.init_empty_repo($1::uuid, $2::uuid)`, [
    scope_id,
    store_id
  ]);

  await insertNode(['page1', 'section1', 'container1'], {
    __type: 'ContainerComponent',
    tint: true,
    color: '#343434',
    style: {
      fontSize: '1px'
    }
  });

  await setProps(['page1', 'section1'], {
    __type: 'SectionComponent',
    tint: true,
    color: 'green'
  });

  await setProps(['page1'], {
    __type: 'PageComponent',
    title: 'My Page'
  });

  const [ref] = await pg.any(
    `SELECT * FROM object_tree_public.ref WHERE scope_id = $1 LIMIT 1`,
    [scope_id]
  );

  const [commit] = await pg.any(
    `SELECT * FROM object_tree_public.commit WHERE id = $1 LIMIT 1`,
    [ref.commit_id]
  );

  const all = await pg.any(
    `SELECT * FROM object_store_public.get_all_objects_from_root($1::uuid, $2::uuid)`,
    [scope_id, commit.tree_id]
  );
  expect(snapshot(all)).toMatchSnapshot();
});

