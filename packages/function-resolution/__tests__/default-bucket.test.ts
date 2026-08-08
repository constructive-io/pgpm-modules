import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

// Deterministic fixture ids.
const PLATFORM_DB = '11111111-1111-1111-1111-111111111111';
const TENANT_DB = '22222222-2222-2222-2222-222222222222';
// A tenant that never labelled a default bucket.
const BARE_DB = '33333333-3333-3333-3333-333333333333';
// A tenant that labelled two, which is a tagging mistake and not a coin flip.
const AMBIGUOUS_DB = '44444444-4444-4444-4444-444444444444';
// A tenant whose own default must never answer somebody else's probe.
const OTHER_DB = '55555555-5555-5555-5555-555555555555';

const ids: Record<string, string> = {};

// The database's default bucket: the answer to "store this file" when no client
// named a bucket. It is a labelled bucket resolved by the same exactly-one rule
// capabilities use — never a literal, never an environment setting, never a
// fallback to another tenant's storage.
describe('default bucket resolution', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());

    await pg.query(
      `INSERT INTO metaschema_public.database (id, name, platform)
       VALUES ($1, 'platform_db', true), ($2, 'tenant_db', false),
              ($3, 'bare_db', false), ($4, 'ambiguous_db', false),
              ($5, 'other_db', false)`,
      [PLATFORM_DB, TENANT_DB, BARE_DB, AMBIGUOUS_DB, OTHER_DB]
    );

    // The published bucket plane, as the catalog-sync triggers maintain it.
    await pg.query(`CREATE SCHEMA catalog_private`);
    await pg.query(
      `CREATE TABLE catalog_private.buckets (
         id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
         owner_scope text NOT NULL,
         owner_key uuid,
         is_visible boolean NOT NULL DEFAULT false,
         database_id uuid NOT NULL,
         key text NOT NULL,
         type text NOT NULL,
         physical_name text,
         tags text[]
       )`
    );

    const bucket = async (
      database: string,
      key: string,
      type: string,
      tags: string[]
    ) => {
      const row = await pg.one(
        `INSERT INTO catalog_private.buckets
           (owner_scope, owner_key, is_visible, database_id, key, type, physical_name, tags)
         VALUES ('database', $1, false, $1, $2, $3, $4, $5) RETURNING id`,
        [database, key, type, `phys-${key}`, tags]
      );
      return row.id;
    };

    ids.default = await bucket(TENANT_DB, 'default', 'private', ['default']);
    ids.defaultPublic = await bucket(TENANT_DB, 'default-public', 'public', [
      'default-public',
    ]);
    ids.avatars = await bucket(TENANT_DB, 'avatars', 'public', ['avatars']);

    ids.otherDefault = await bucket(OTHER_DB, 'default', 'private', ['default']);

    ids.ambiguousOne = await bucket(AMBIGUOUS_DB, 'documents', 'private', [
      'default',
    ]);
    ids.ambiguousTwo = await bucket(AMBIGUOUS_DB, 'uploads', 'private', [
      'default',
    ]);
  });

  afterAll(async () => {
    await teardown();
  });

  it('the reserved tag vocabulary is one fact, not a literal per call site', async () => {
    const [tags] = await pg.any(
      `SELECT function_resolution.default_bucket_tag(false) AS private_tag,
              function_resolution.default_bucket_tag(true) AS public_tag`
    );
    expect(tags).toEqual({ private_tag: 'default', public_tag: 'default-public' });
  });

  it('resolves the database default without anyone naming a bucket', async () => {
    const [row] = await pg.any(
      `SELECT bucket_id, resolved_key, bucket_type, physical_name, owner_database_id
       FROM function_resolution.resolve_default_bucket($1, 'database', $1, false)`,
      [TENANT_DB]
    );
    expect(row).toEqual({
      bucket_id: ids.default,
      resolved_key: 'default',
      bucket_type: 'private',
      physical_name: 'phys-default',
      owner_database_id: TENANT_DB,
    });
  });

  it('public access resolves the CDN-served default, not the private one', async () => {
    const [row] = await pg.any(
      `SELECT bucket_id, bucket_type
       FROM function_resolution.resolve_default_bucket($1, 'database', $1, true)`,
      [TENANT_DB]
    );
    expect(row).toEqual({ bucket_id: ids.defaultPublic, bucket_type: 'public' });
  });

  it('an explicit logical key overrides the default and resolves by the same rule', async () => {
    const [row] = await pg.any(
      `SELECT bucket_id, resolved_key
       FROM function_resolution.resolve_default_bucket($1, 'database', $1, false, 'avatars')`,
      [TENANT_DB]
    );
    expect(row).toEqual({ bucket_id: ids.avatars, resolved_key: 'avatars' });
  });

  it('an explicit key nothing carries raises rather than falling back to the default', async () => {
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_default_bucket($1, 'database', $1, false, 'nope')`,
        [TENANT_DB]
      )
    ).rejects.toThrow(/STORAGE_DEFAULT_BUCKET_NOT_FOUND/);
  });

  it('a blank key is a caller bug, not a request for the default', async () => {
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_default_bucket($1, 'database', $1, false, '  ')`,
        [TENANT_DB]
      )
    ).rejects.toThrow(/STORAGE_BUCKET_KEY_BLANK/);
  });

  it('a database with no default bucket raises', async () => {
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_default_bucket($1, 'database', $1, false)`,
        [BARE_DB]
      )
    ).rejects.toThrow(/STORAGE_DEFAULT_BUCKET_NOT_FOUND/);
  });

  it('another tenant default is never borrowed', async () => {
    // OTHER_DB has a bucket tagged 'default'; BARE_DB still has none.
    const [foreign] = await pg.any(
      `SELECT bucket_id FROM function_resolution.resolve_default_bucket($1, 'database', $1, false)`,
      [OTHER_DB]
    );
    expect(foreign.bucket_id).toBe(ids.otherDefault);

    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_default_bucket($1, 'database', $1, false)`,
        [BARE_DB]
      )
    ).rejects.toThrow(/STORAGE_DEFAULT_BUCKET_NOT_FOUND/);
  });

  it('two default buckets raise, naming the candidates', async () => {
    let failure: (Error & { detail?: string }) | null = null;
    try {
      await pg.any(
        `SELECT * FROM function_resolution.resolve_default_bucket($1, 'database', $1, false)`,
        [AMBIGUOUS_DB]
      );
    } catch (error) {
      failure = error as Error & { detail?: string };
    }

    expect(failure).not.toBeNull();
    expect(failure!.message).toMatch(/STORAGE_DEFAULT_BUCKET_AMBIGUOUS/);

    const detail = JSON.parse(failure!.detail!);
    expect(detail.code).toBe('STORAGE_DEFAULT_BUCKET_AMBIGUOUS');
    expect(detail.context.tag).toBe('default');
    expect(detail.context.candidates).toEqual([
      { bucket_id: ids.ambiguousOne, key: 'documents', type: 'private' },
      { bucket_id: ids.ambiguousTwo, key: 'uploads', type: 'private' },
    ]);
  });
});
