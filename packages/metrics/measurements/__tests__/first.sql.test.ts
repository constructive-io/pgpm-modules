import { getConnections } from './utils';

let teardown: () => Promise<void>, db: any;

describe('signup', () => {
  beforeAll(async () => {
    ({ db, teardown } = await getConnections());
  });
  beforeEach(async () => {
    await db.beforeEach();
  });
  afterEach(async () => {
    await db.afterEach();
  });
  afterAll(async () => {
    await teardown();
  });
  describe('has a database', () => {
    it('schema exists', async () => {
      const res = await db.any(
        "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'measurements'"
      );
      expect(Array.isArray(res)).toBe(true);
      expect(res.length).toBe(1);
      expect(res[0].schema_name).toBe('measurements');
    });
  });
});
