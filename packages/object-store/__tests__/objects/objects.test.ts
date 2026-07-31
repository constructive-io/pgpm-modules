jest.setTimeout(30000);

import { getConnections, PgTestClient } from 'constructive-test';
import { snapshot } from 'pgsql-test/utils';

let pg: PgTestClient;
let teardown: () => Promise<void>;

const scope_id = 'd0f7ab73-356f-4aac-b9cb-d1a4274906d6';

describe('custom objects', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
  });

  afterAll(async () => {
    await teardown();
  });

  beforeEach(async () => {
    await pg.beforeEach();
  });

  afterEach(async () => {
    await pg.afterEach();
  });

  it('basic structure', async () => {
    const [grandchild1] = await pg.any(
      `INSERT INTO object_store_public.object (scope_id, data)
       VALUES ($1, $2)
       RETURNING *`,
      [scope_id, { name: 'grandchild1' }]
    );

    const [leaf] = await pg.any(
      `INSERT INTO object_store_public.object (scope_id)
       VALUES ($1)
       RETURNING *`,
      [scope_id]
    );

    const [grandchild2] = await pg.any(
      `INSERT INTO object_store_public.object (scope_id, data, kids, ktree)
       VALUES ($1, $2, $3::uuid[], $4::text[])
       RETURNING *`,
      [scope_id, { name: 'grandchild2' }, [leaf.id, leaf.id, leaf.id], ['x', 'y', 'z']]
    );

    const [child1] = await pg.any(
      `INSERT INTO object_store_public.object (scope_id, data, kids, ktree)
       VALUES ($1, $2, $3::uuid[], $4::text[])
       RETURNING *`,
      [scope_id, { name: 'child1' }, [grandchild1.id, grandchild2.id], ['c', 'd']]
    );

    const [child2] = await pg.any(
      `INSERT INTO object_store_public.object (scope_id, data, kids, ktree)
       VALUES ($1, $2, $3::uuid[], $4::text[])
       RETURNING *`,
      [scope_id, { name: 'child2' }, [grandchild1.id, grandchild2.id], ['e', 'f']]
    );

    const [root] = await pg.any(
      `INSERT INTO object_store_public.object (scope_id, kids, ktree)
       VALUES ($1, $2::uuid[], $3::text[])
       RETURNING *`,
      [scope_id, [child1.id, child2.id], ['a', 'b']]
    );

    const stripDatabaseId = (r: any) => {
      delete r.scope_id;
      return r;
    };

    const result1 = await pg.any(
      `SELECT * FROM object_store_public.get_all_objects_from_root(
        s_id := $1::uuid,
        id := $2::uuid
      )`,
      [scope_id, root.id]
    );
    expect(snapshot(result1.map(stripDatabaseId))).toMatchSnapshot();

    const result2 = await pg.any(
      `SELECT * FROM object_store_public.get_path_objects_from_root(
        s_id := $1::uuid,
        id := $2::uuid,
        path := $3::text[]
      )`,
      [scope_id, root.id, ['a', 'c']]
    );
    expect(snapshot(result2.map(stripDatabaseId))).toMatchSnapshot();

    const result3 = await pg.any(
      `SELECT * FROM object_store_public.get_path_objects_from_root(
        s_id := $1::uuid,
        id := $2::uuid,
        path := $3::text[]
      )`,
      [scope_id, root.id, ['b', 'f']]
    );
    expect(snapshot(result3.map(stripDatabaseId))).toMatchSnapshot();

    const result4 = await pg.any(
      `SELECT * FROM object_store_public.get_path_objects_from_root(
        s_id := $1::uuid,
        id := $2::uuid,
        path := $3::text[]
      )`,
      [scope_id, root.id, ['b', 'e']]
    );
    expect(snapshot(result4.map(stripDatabaseId))).toMatchSnapshot();

    const node1 = await pg.any(
      `SELECT * FROM object_store_public.get_node_at_path(
        s_id := $1::uuid,
        id := $2::uuid,
        path := $3::text[]
      )`,
      [scope_id, root.id, []]
    );
    expect(snapshot(node1.map(stripDatabaseId))).toMatchSnapshot();

    const node2 = await pg.any(
      `SELECT * FROM object_store_public.get_node_at_path(
        s_id := $1::uuid,
        id := $2::uuid,
        path := $3::text[]
      )`,
      [scope_id, root.id, ['b', 'e']]
    );
    expect(snapshot(node2.map(stripDatabaseId))).toMatchSnapshot();

    const [update1Result] = await pg.any(
      `SELECT object_store_public.update_node_at_path(
        s_id := $1::uuid,
        root := $2::uuid,
        path := $3::text[],
        data := $4::jsonb,
        kids := $5::uuid[],
        ktree := $6::text[]
      ) AS new_root`,
      [scope_id, root.id, ['b', 'f', 'y'], { 'hello there': 23 }, [], []]
    );

    const query1 = await pg.any(
      `SELECT * FROM object_store_public.get_all_objects_from_root(
        s_id := $1::uuid,
        id := $2::uuid
      )`,
      [scope_id, update1Result.new_root]
    );
    expect(snapshot(query1.map(stripDatabaseId))).toMatchSnapshot();

    const [update2Result] = await pg.any(
      `SELECT object_store_public.insert_node_at_path(
        s_id := $1::uuid,
        root := $2::uuid,
        path := $3::text[],
        data := $4::jsonb,
        kids := $5::uuid[],
        ktree := $6::text[]
      ) AS new_root`,
      [scope_id, root.id, ['b', 'f', 'y', 'z', 'x', 'deployment.yaml'], { 'hello there': 23 }, [], []]
    );

    const query2 = await pg.any(
      `SELECT * FROM object_store_public.get_all_objects_from_root(
        s_id := $1::uuid,
        id := $2::uuid
      )`,
      [scope_id, update2Result.new_root]
    );
    expect(snapshot(query2.map(stripDatabaseId))).toMatchSnapshot();
  });
});

