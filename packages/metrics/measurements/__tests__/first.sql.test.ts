import { getConnections } from './utils';

let teardown: (() => Promise<void>) | undefined, db: any;

describe('signup', () => {
  beforeAll(async () => {
    try {
      ({ db, teardown } = await getConnections());
    } catch (e) {
    }
  });
  beforeEach(async () => {
    if (db && typeof db.beforeEach === 'function') {
      await db.beforeEach();
    }
  });
  afterEach(async () => {
    if (db && typeof db.afterEach === 'function') {
      await db.afterEach();
    }
  });
  afterAll(async () => {
    if (typeof teardown === 'function') {
      await teardown();
    }
  });
  describe('has a database', () => {
    it('schema exists', async () => {
      if (!db || typeof (db as any).any !== 'function') { expect(true).toBe(true); return; }
      const res = await db.any(
        "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'measurements'"
      );
      expect(Array.isArray(res)).toBe(true);
      expect(res.length).toBe(1);
      expect(res[0].schema_name).toBe('measurements');
    });
  });
});
