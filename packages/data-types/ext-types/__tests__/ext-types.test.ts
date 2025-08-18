import { getConnections } from 'pgsql-test';

let teardown: () => Promise<void>;
let db: any;

beforeAll(async () => {
  ({ db, teardown } = await getConnections());
});

afterAll(async () => {
  try {
    await teardown();
  } catch {}
});

describe('@launchql/ext-types', () => {
  it('creates domain types', async () => {
    const { typname } = await db.one(
      `SELECT typname FROM pg_type WHERE typname = 'url'`
    );
    expect(typname).toBe('url');
  });
});
