jest.setTimeout(30000);

import { getConnections, PgTestClient } from 'pgsql-test';
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

describe('commits', () => {
  it('create a ref', async () => {
    const [root] = await pg.any(
      `INSERT INTO object_store_public.object (scope_id)
       VALUES ($1)
       RETURNING *`,
      [scope_id]
    );

    const [ref] = await pg.any(
      `INSERT INTO object_tree_public.ref (scope_id, store_id, name)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [scope_id, store_id, 'master']
    );

    const [commit] = await pg.any(
      `INSERT INTO object_tree_public.commit (scope_id, store_id, message, tree_id)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [scope_id, store_id, 'first commit', root.id]
    );

    await pg.any(
      `UPDATE object_tree_public.ref
       SET commit_id = $1
       WHERE id = $2`,
      [commit.id, ref.id]
    );

    const res = await pg.any(
      `SELECT * FROM object_tree_public.set_and_commit(
        s_id := $1::uuid,
        store_id := $2::uuid,
        refname := $3::text,
        path := $4::text[],
        data := $5::jsonb,
        kids := $6::uuid[],
        ktree := $7::text[]
      )`,
      [scope_id, store_id, 'master', ['a', 'b', 'c.yaml'], { content: 'type: hi' }, [], []]
    );
    expect(snapshot(res)).toMatchSnapshot();

    const get1 = await pg.any(
      `SELECT * FROM object_tree_public.get_object_at_path(
        s_id := $1::uuid,
        store_id := $2::uuid,
        path := $3::text[],
        refname := $4::text
      )`,
      [scope_id, store_id, ['a', 'b', 'c.yaml'], 'master']
    );
    expect(snapshot(get1)).toMatchSnapshot();
  });
});

