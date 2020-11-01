import { getConnections } from './utils';

let db, dbs, teardown;
const objs = {
  tables: {}
};

beforeAll(async () => {
  ({ db, teardown } = await getConnections());
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
  await db.any(`
  insert into secrets_schema.secrets_table
( secrets_owned_field,
  name,
  secrets_value_field,
  secrets_enc_field
) values
(
'dc474833-318a-41f5-9239-ee563ab657a6',
'my-secret-name',
'my-secret',
'pgp'
)
;
  `);
  const res = await db.any('SELECT * FROM secrets_schema.secrets_table');
  console.log(res);
});
