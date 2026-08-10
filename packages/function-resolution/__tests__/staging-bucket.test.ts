import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

// Deterministic fixture ids.
const TENANT_DB = '22222222-2222-2222-2222-222222222222';
// A tenant whose storage bootstrap never labelled a staging bucket.
const BARE_DB = '33333333-3333-3333-3333-333333333333';
// A tenant that labelled two, which is a tagging mistake and not a coin flip.
const AMBIGUOUS_DB = '44444444-4444-4444-4444-444444444444';

const ids: Record<string, string> = {};

// The database's staging bucket: the answer to "where does an upload land before
// anything has vouched for it". It resolves by the same exactly-one tag rule the
// default bucket uses, so staging is not a second lookup mechanism — and a
// module that has no staging bucket raises rather than staging into a permanent
// one.
describe('staging bucket resolution', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());

    await pg.query(
      `INSERT INTO metaschema_public.database (id, name, platform)
       VALUES ($1, 'tenant_db', false), ($2, 'bare_db', false),
              ($3, 'ambiguous_db', false)`,
      [TENANT_DB, BARE_DB, AMBIGUOUS_DB]
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
    ids.staging = await bucket(TENANT_DB, 'default-temp', 'temp', [
      'default-temp',
    ]);

    // A permanent bucket carrying the staging tag is not a staging bucket: the
    // type filter is part of the rule, not a hint.
    ids.mislabelled = await bucket(BARE_DB, 'uploads', 'private', [
      'default-temp',
    ]);

    ids.ambiguousOne = await bucket(AMBIGUOUS_DB, 'staging_a', 'temp', [
      'default-temp',
    ]);
    ids.ambiguousTwo = await bucket(AMBIGUOUS_DB, 'staging_b', 'temp', [
      'default-temp',
    ]);
  });

  afterAll(async () => {
    await teardown();
  });

  it('the reserved staging tag is one fact, not a literal per call site', async () => {
    const [row] = await pg.any(
      `SELECT function_resolution.staging_bucket_tag() AS staging_tag`
    );
    expect(row).toEqual({ staging_tag: 'default-temp' });
  });

  it('resolves the database staging bucket without anyone naming one', async () => {
    const [row] = await pg.any(
      `SELECT bucket_id, resolved_key, bucket_type, physical_name, owner_database_id
       FROM function_resolution.resolve_staging_bucket($1, 'database', $1)`,
      [TENANT_DB]
    );
    expect(row).toEqual({
      bucket_id: ids.staging,
      resolved_key: 'default-temp',
      bucket_type: 'temp',
      physical_name: 'phys-default-temp',
      owner_database_id: TENANT_DB,
    });
  });

  it('a database with no staging bucket raises rather than staging into a permanent one', async () => {
    // BARE_DB does carry the tag — on a private bucket, which is exactly the
    // case that must not resolve.
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_staging_bucket($1, 'database', $1)`,
        [BARE_DB]
      )
    ).rejects.toThrow(/STORAGE_STAGING_BUCKET_NOT_FOUND/);
  });

  it('two staging buckets raise, naming the candidates', async () => {
    let failure: (Error & { detail?: string }) | null = null;
    try {
      await pg.any(
        `SELECT * FROM function_resolution.resolve_staging_bucket($1, 'database', $1)`,
        [AMBIGUOUS_DB]
      );
    } catch (error) {
      failure = error as Error & { detail?: string };
    }

    expect(failure).not.toBeNull();
    expect(failure!.message).toMatch(/STORAGE_STAGING_BUCKET_AMBIGUOUS/);

    const detail = JSON.parse(failure!.detail!);
    expect(detail.code).toBe('STORAGE_STAGING_BUCKET_AMBIGUOUS');
    expect(detail.context.tag).toBe('default-temp');
    expect(detail.context.candidates).toEqual([
      { bucket_id: ids.ambiguousOne, key: 'staging_a', type: 'temp' },
      { bucket_id: ids.ambiguousTwo, key: 'staging_b', type: 'temp' },
    ]);
  });
});
