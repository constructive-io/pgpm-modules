jest.setTimeout(30000);

import { getConnections, PgTestClient } from 'pgsql-test';
import cases from 'jest-in-case';

let pg: PgTestClient;
let teardown: () => Promise<void>;

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

cases(
  'get_table_name',
  async (opts: { name: string; result: string }) => {
    const [{ get_table_name }] = await pg.any(
      'SELECT * FROM inflection_db.get_table_name($1)',
      [opts.name]
    );
    expect(get_table_name).toEqual(opts.result);
  },
  [
    { name: 'My Table', result: 'my_tables' },
    { name: 'My_Tables', result: 'my_tables' }
  ]
);

cases(
  'get_table_name variadic',
  async (opts: { name: string; args: (string | null)[]; result: string }) => {
    const [{ get_table_name }] = await pg.any(
      'SELECT * FROM inflection_db.get_table_name($1::text[])',
      [opts.args]
    );
    expect(get_table_name).toEqual(opts.result);
  },
  [
    { name: 'My Table', args: ['My', 'Table'], result: 'my_tables' },
    {
      name: 'My_Tables',
      args: [null, 'My_Tables', 'Yo'],
      result: 'my_tables_yos'
    }
  ]
);

cases(
  'get_field_name',
  async (opts: { name: string; result: string }) => {
    const [{ get_field_name }] = await pg.any(
      'SELECT * FROM inflection_db.get_field_name( $1 )',
      [opts.name]
    );
    expect(get_field_name).toEqual(opts.result);
  },
  [
    { name: 'My Table', result: 'my_table' },
    { name: 'My_Tables', result: 'my_tables' }
  ]
);

cases(
  'get_table_plural_name',
  async (opts: { name: string; result: string }) => {
    const [{ get_table_plural_name }] = await pg.any(
      'SELECT * FROM inflection_db.get_table_plural_name( $1 )',
      [opts.name]
    );
    expect(get_table_plural_name).toEqual(opts.result);
  },
  [
    { name: 'My Table', result: 'my_tables' },
    { name: 'My_Tables', result: 'my_tables' }
  ]
);

cases(
  'get_table_singular_name',
  async (opts: { name: string; result: string }) => {
    const [{ get_table_singular_name }] = await pg.any(
      'SELECT * FROM inflection_db.get_table_singular_name( $1 )',
      [opts.name]
    );
    expect(get_table_singular_name).toEqual(opts.result);
  },
  [
    { name: 'My Table', result: 'my_table' },
    { name: 'My_Tables', result: 'my_table' }
  ]
);

cases(
  'get_primary_key_index_name',
  async (opts: { name: string; result: string }) => {
    const [{ get_primary_key_index_name }] = await pg.any(
      'SELECT * FROM inflection_db.get_primary_key_index_name( $1 )',
      [opts.name]
    );
    expect(get_primary_key_index_name).toEqual(opts.result);
  },
  [
    { name: 'My Table', result: 'my_tables_pkey' },
    { name: 'My_Tables', result: 'my_tables_pkey' },
    { name: 'my child', result: 'my_children_pkey' }
  ]
);

cases(
  'get_foreign_key_index_name',
  async (opts: { name: string; field: string; result: string }) => {
    const [{ get_foreign_key_index_name }] = await pg.any(
      'SELECT * FROM inflection_db.get_foreign_key_index_name( $1, $2 )',
      [opts.name, opts.field]
    );
    expect(get_foreign_key_index_name).toEqual(opts.result);
  },
  [
    { name: 'men', field: 'user', result: 'men_user_fkey' },
    { name: 'man', field: 'user', result: 'men_user_fkey' },
    { name: 'tables', field: 'user', result: 'tables_user_fkey' },
    { name: 'table', field: 'user', result: 'tables_user_fkey' }
  ]
);

cases(
  'get_foreign_key_field_name',
  async (opts: { name: string; result: string }) => {
    const [{ get_foreign_key_field_name }] = await pg.any(
      'SELECT * FROM inflection_db.get_foreign_key_field_name( $1 )',
      [opts.name]
    );
    expect(get_foreign_key_field_name).toEqual(opts.result);
  },
  [
    { name: 'men', result: 'man_id' },
    { name: 'man', result: 'man_id' },
    { name: 'tables', result: 'table_id' },
    { name: 'table', result: 'table_id' },
    { name: 'users', result: 'user_id' },
    { name: 'user', result: 'user_id' }
  ]
);

cases(
  'get_unique_index_name',
  async (opts: { name: string; fields: string[]; result: string }) => {
    const [{ get_unique_index_name }] = await pg.any(
      'SELECT * FROM inflection_db.get_unique_index_name( $1, $2 )',
      [opts.name, opts.fields]
    );
    expect(get_unique_index_name).toEqual(opts.result);
  },
  [
    {
      name: 'User',
      fields: ['username', 'email'],
      result: 'users_username_email_key'
    },
    {
      name: 'Posts',
      fields: ['username', 'created_at', 'email'],
      result: 'posts_username_created_at_email_key'
    }
  ]
);

cases(
  'get_check_constraint_name',
  async (opts: { name: string; fields: string[]; result: string }) => {
    const [{ get_check_constraint_name }] = await pg.any(
      'SELECT * FROM inflection_db.get_check_constraint_name( $1, $2 )',
      [opts.name, opts.fields]
    );
    expect(get_check_constraint_name).toEqual(opts.result);
  },
  [
    {
      name: 'User',
      fields: ['username', 'email'],
      result: 'users_username_email_chk'
    },
    {
      name: 'Posts',
      fields: ['username', 'created_at', 'email'],
      result: 'posts_username_created_at_email_chk'
    }
  ]
);

cases(
  'get_index_name',
  async (opts: { name: string; fields: string[]; result: string }) => {
    const [{ get_index_name }] = await pg.any(
      'SELECT * FROM inflection_db.get_index_name( $1, $2 )',
      [opts.name, opts.fields]
    );
    expect(get_index_name).toEqual(opts.result);
  },
  [
    {
      name: 'User',
      fields: ['username', 'email'],
      result: 'users_username_email_idx'
    },
    {
      name: 'Posts',
      fields: ['username', 'created_at', 'email'],
      result: 'posts_username_created_at_email_idx'
    }
  ]
);

