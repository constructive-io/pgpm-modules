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

  it('deploy example', async () => {
    const [root] = await pg.any(
      `INSERT INTO object_store_public.object (scope_id)
       VALUES ($1)
       RETURNING *`,
      [scope_id]
    );

    const serviceYaml = `apiVersion: v1
kind: Service
metadata:
    name: launchql-service
    namespace: webinc
spec:
    type: NodePort
    ports:
    - name: launchql
        port: 7777
        targetPort: 7777
        protocol: TCP
    selector:
    app: constructive`;

    const [update1Result] = await pg.any(
      `SELECT object_store_public.insert_node_at_path(
        s_id := $1::uuid,
        root := $2::uuid,
        path := $3::text[],
        data := $4::jsonb,
        kids := $5::uuid[],
        ktree := $6::text[]
      ) AS new_root`,
      [scope_id, root.id, ['k8s', 'launchql', 'service.yaml'], { content: serviceYaml }, [], []]
    );

    const indexJs = `export default (req, context) => {
            return true;
        });`;

    const [update2Result] = await pg.any(
      `SELECT object_store_public.insert_node_at_path(
        s_id := $1::uuid,
        root := $2::uuid,
        path := $3::text[],
        data := $4::jsonb,
        kids := $5::uuid[],
        ktree := $6::text[]
      ) AS new_root`,
      [scope_id, update1Result.new_root, ['fns', 'email-fn', 'index.js'], { content: indexJs }, [], []]
    );

    const query1 = await pg.any(
      `SELECT * FROM object_store_public.get_all_objects_from_root(
        s_id := $1::uuid,
        id := $2::uuid
      )`,
      [scope_id, update2Result.new_root]
    );

    const query1map = query1.map((r: any) => {
      delete r.scope_id;
      return r;
    });

    expect(snapshot(query1map)).toMatchSnapshot();
  });
});

