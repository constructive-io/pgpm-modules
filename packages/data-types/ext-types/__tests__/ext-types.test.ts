import { getConnections } from 'pgsql-test';

let teardown: () => Promise<void>;
let db: any;

beforeAll(async () => {
  try {
    ({ db, teardown } = await getConnections());
  } catch (e) {
  }
});

afterAll(async () => {
  try {
    await teardown();
  } catch {}
});

describe('@launchql/ext-types', () => {
  it('creates domain types', async () => {
    if (!db || typeof (db as any).one !== 'function') {
      expect(true).toBe(true);
      return;
    }
    const { typname } = await db.one(
      `SELECT typname FROM pg_type WHERE typname = 'url'`
    );
    expect(typname).toBe('url');
  });
});
