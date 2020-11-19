import { getConnections } from './utils';

let db, dbs, conn, teardown;
const objs = {
  tables: {}
};

beforeAll(async () => {
  ({ db, conn, teardown } = await getConnections());
  dbs = db.helper('yourschema');
});

afterAll(async () => {
  try {
    //try catch here allows us to see the sql parsing issues!
    await teardown();
  } catch (e) {
    // noop
  }
});

beforeEach(async () => {
  await db.beforeEach();
});

afterEach(async () => {
  await db.afterEach();
});

it('a test here', async () => {
  await db.any('INSERT INTO services_public.services DEFAULT VALUES');
  const res = await db.any('SELECT * FROM services_public.services');
  console.log(res);
});
