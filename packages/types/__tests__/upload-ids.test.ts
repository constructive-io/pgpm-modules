import { getConnections, PgTestClient } from 'pgsql-test';

// upload_ids(upload[]) is the one indexable expression for a column holding many
// uploads: storage garbage collection and the files-to-document sync trigger both
// key off it, and a GIN index is built over it.

const fileA = '0d1e3d64-1e2a-4c7f-9c3a-6f7f9f2b1c44';
const fileB = '9a7f1c2e-4b6d-4a11-8f30-2c5d7e9a0b13';

let pg: PgTestClient;
let teardown: () => Promise<void>;

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());
});

afterAll(async () => {
  await teardown();
});

const uploadIds = async (uploads: unknown[]): Promise<string[] | null> => {
  const { ids } = await pg.one<{ ids: string[] | null }>(
    `SELECT upload_ids($1::jsonb[]::upload[]) AS ids`,
    [uploads.map((u) => JSON.stringify(u))]
  );
  return ids;
};

describe('upload_ids', () => {
  it('returns the file ids in element order', async () => {
    expect(await uploadIds([{ id: fileA }, { id: fileB }])).toEqual([fileA, fileB]);
  });

  it('skips elements that name no file', async () => {
    expect(
      await uploadIds([{ url: 'https://example.com/a.pdf' }, { id: fileB }])
    ).toEqual([fileB]);
  });

  it('returns an empty array for an empty array', async () => {
    expect(await uploadIds([])).toEqual([]);
  });

  it('is strict: null in, null out', async () => {
    const { ids } = await pg.one<{ ids: string[] | null }>(
      `SELECT upload_ids(NULL::upload[]) AS ids`
    );
    expect(ids).toBeNull();
  });

  it('is immutable, so it can back an expression index', async () => {
    const { provolatile, proparallel } = await pg.one<{
      provolatile: string;
      proparallel: string;
    }>(
      `SELECT provolatile, proparallel
       FROM pg_proc
       WHERE proname = 'upload_ids'`
    );
    expect(provolatile).toBe('i');
    expect(proparallel).toBe('s');
  });

  it('supports a GIN index over the ids of an upload array column', async () => {
    await pg.any(`
CREATE TABLE messages (
  id serial PRIMARY KEY,
  attachments upload[]
);
CREATE INDEX messages_attachments_idx ON messages USING gin (upload_ids(attachments));
`);
    await pg.any(
      `INSERT INTO messages (attachments) VALUES (ARRAY[$1::jsonb::upload, $2::jsonb::upload])`,
      [JSON.stringify({ id: fileA }), JSON.stringify({ id: fileB })]
    );

    const { count } = await pg.one<{ count: string }>(
      `SELECT count(*)::text AS count
       FROM messages
       WHERE upload_ids(attachments) && ARRAY[$1::text]`,
      [fileB]
    );
    expect(count).toBe('1');
  });
});
