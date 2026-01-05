import { getConnections, PgTestClient, snapshot } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

describe('metaschema_schema functionality', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
  });

  afterAll(async () => {
    await teardown();
  });

  beforeEach(async () => {
    await pg.beforeEach();
    await pg.any(`GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO public`);
  });

  afterEach(async () => {
    await pg.afterEach();
  });

  it('should create database independently', async () => {
    const owner_id = '07281002-1699-4762-57e3-ab1b92243120';
    
    const [database] = await pg.any(
      `INSERT INTO metaschema_public.database (owner_id, name) 
       VALUES ($1, $2) 
       RETURNING *`,
      [owner_id, 'test-db']
    );
    
    expect(database.owner_id).toBe(owner_id);
    expect(database.name).toBe('test-db');
    expect(database.id).toBeDefined();
  });

  it('should create schema for database', async () => {
    const owner_id = '07281002-1699-4762-57e3-ab1b92243120';
    
    const [database] = await pg.any(
      `INSERT INTO metaschema_public.database (owner_id, name) 
       VALUES ($1, $2) 
       RETURNING *`,
      [owner_id, 'test-db-for-schema']
    );
    
    const [schema] = await pg.any(
      `INSERT INTO metaschema_public.schema (database_id, schema_name, name) 
       VALUES ($1, $2, $3) 
       RETURNING *`,
      [database.id, 'app_public', 'public']
    );
    
    expect(schema.database_id).toBe(database.id);
    expect(schema.schema_name).toBe('app_public');
    expect(schema.name).toBe('public');
  });

  it('should create table for schema', async () => {
    const owner_id = '07281002-1699-4762-57e3-ab1b92243120';
    
    const [database] = await pg.any(
      `INSERT INTO metaschema_public.database (owner_id, name) 
       VALUES ($1, $2) 
       RETURNING *`,
      [owner_id, 'test-db-for-table']
    );
    
    const [schema] = await pg.any(
      `INSERT INTO metaschema_public.schema (database_id, schema_name, name) 
       VALUES ($1, $2, $3) 
       RETURNING *`,
      [database.id, 'app_public', 'public']
    );
    
    const [table] = await pg.any(
      `INSERT INTO metaschema_public.table (database_id, schema_id, table_name, name) 
       VALUES ($1, $2, $3, $4) 
       RETURNING *`,
      [database.id, schema.id, 'users', 'users']
    );
    
    expect(table.database_id).toBe(database.id);
    expect(table.schema_id).toBe(schema.id);
    expect(table.table_name).toBe('users');
    expect(table.name).toBe('users');
  });

  it('should create field for table', async () => {
    const owner_id = '07281002-1699-4762-57e3-ab1b92243120';
    
    const [database] = await pg.any(
      `INSERT INTO metaschema_public.database (owner_id, name) 
       VALUES ($1, $2) 
       RETURNING *`,
      [owner_id, 'test-db-for-field']
    );
    
    const [schema] = await pg.any(
      `INSERT INTO metaschema_public.schema (database_id, schema_name, name) 
       VALUES ($1, $2, $3) 
       RETURNING *`,
      [database.id, 'app_public', 'public']
    );
    
    const [table] = await pg.any(
      `INSERT INTO metaschema_public.table (database_id, schema_id, table_name, name) 
       VALUES ($1, $2, $3, $4) 
       RETURNING *`,
      [database.id, schema.id, 'users', 'users']
    );
    
    const [field] = await pg.any(
      `INSERT INTO metaschema_public.field (table_id, field_name, name, type) 
       VALUES ($1, $2, $3, $4) 
       RETURNING *`,
      [table.id, 'email', 'email', 'text']
    );
    
    expect(field.table_id).toBe(table.id);
    expect(field.field_name).toBe('email');
    expect(field.name).toBe('email');
    expect(field.type).toBe('text');
  });

  it('should create extension', async () => {
    const [extension] = await pg.any(
      `INSERT INTO metaschema_public.extension (name, public_schemas, private_schemas) 
       VALUES ($1, $2, $3) 
       RETURNING *`,
      ['pgcrypto', ['crypto_public'], ['crypto_private']]
    );
    
    expect(extension.name).toBe('pgcrypto');
    expect(extension.public_schemas).toEqual(['crypto_public']);
    expect(extension.private_schemas).toEqual(['crypto_private']);
  });

  it('should associate extension with database', async () => {
    const owner_id = '07281002-1699-4762-57e3-ab1b92243120';
    
    const [database] = await pg.any(
      `INSERT INTO metaschema_public.database (owner_id, name) 
       VALUES ($1, $2) 
       RETURNING *`,
      [owner_id, 'test-db-for-extension']
    );
    
    const [extension] = await pg.any(
      `INSERT INTO metaschema_public.extension (name, public_schemas, private_schemas) 
       VALUES ($1, $2, $3) 
       RETURNING *`,
      ['uuid-ossp', ['uuid_public'], ['uuid_private']]
    );
    
    const [dbExtension] = await pg.any(
      `INSERT INTO metaschema_public.database_extension (name, database_id) 
       VALUES ($1, $2) 
       RETURNING *`,
      [extension.name, database.id]
    );
    
    expect(dbExtension.database_id).toBe(database.id);
    expect(dbExtension.name).toBe(extension.name);
  });
});
