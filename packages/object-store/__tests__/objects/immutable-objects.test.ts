jest.setTimeout(30000);

import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

const scope_id = 'd0f7ab73-356f-4aac-b9cb-d1a4274906d6';

const insertObject = async (): Promise<string> => {
  const [row] = await pg.any(
    `INSERT INTO object_store_public.object (scope_id, data)
     VALUES ($1, $2)
     RETURNING id`,
    [scope_id, { name: 'deletable' }]
  );
  return row.id;
};

const countObject = async (id: string): Promise<number> => {
  const [row] = await pg.any(
    `SELECT count(*)::int AS n FROM object_store_public.object o WHERE o.id = $1 AND o.scope_id = $2`,
    [id, scope_id]
  );
  return row.n;
};

describe('immutable objects', () => {
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

  it('deletes an unfrozen object', async () => {
    const id = await insertObject();

    await pg.any(`DELETE FROM object_store_public.object o WHERE o.id = $1 AND o.scope_id = $2`, [id, scope_id]);

    // The BEFORE DELETE trigger has to return OLD: returning NEW (NULL for a
    // delete) cancelled the delete silently and left the row in place.
    expect(await countObject(id)).toBe(0);
  });

  it('refuses to delete a frozen object', async () => {
    const id = await insertObject();
    await pg.any(`UPDATE object_store_public.object o SET frzn = true WHERE o.id = $1 AND o.scope_id = $2`, [
      id,
      scope_id
    ]);

    // The raise aborts the surrounding test transaction, so the delete runs
    // inside a savepoint to keep the row count assertion runnable.
    await pg.any('SAVEPOINT frozen_delete');
    await expect(
      pg.any(`DELETE FROM object_store_public.object o WHERE o.id = $1 AND o.scope_id = $2`, [id, scope_id])
    ).rejects.toThrow(/immutable record/);
    await pg.any('ROLLBACK TO SAVEPOINT frozen_delete');

    expect(await countObject(id)).toBe(1);
  });
});
