import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let db: PgTestClient;
let teardown: () => Promise<void>;

beforeAll(async () => {
  ({ pg, db, teardown } = await getConnections());
});

afterAll(async () => {
  await teardown();
});

beforeEach(async () => {
  await pg.beforeEach();
  await db.beforeEach();
});

afterEach(async () => {
  await db.afterEach();
  await pg.afterEach();
});

const isReserved = async (client: PgTestClient, kind: string, name: string) => {
  const { is_reserved } = await client.one(
    `SELECT reserved_names.is_reserved($1, $2) AS is_reserved`,
    [kind, name]
  );
  return is_reserved;
};

describe('reserved_names.is_reserved', () => {
  it.each(['login', 'admin', 'www', 'status', 'LOGIN', 'Admin'])(
    'reserves the exact subdomain %s, in any case',
    async (name) => {
      expect(await isReserved(pg, 'subdomain', name)).toBe(true);
    }
  );

  it.each(['mystore', 'login2', 'my-login', 'api-docs', 'administrators'])(
    'leaves %s free',
    async (name) => {
      expect(await isReserved(pg, 'subdomain', name)).toBe(false);
    }
  );

  it('reserves every punycode label through the xn-- prefix entry', async () => {
    expect(await isReserved(pg, 'subdomain', 'xn--pple-43d')).toBe(true);
    expect(await isReserved(pg, 'subdomain', 'XN--80ak6aa92e')).toBe(true);
  });

  it('keeps kinds apart', async () => {
    expect(await isReserved(pg, 'username', 'login')).toBe(false);

    await pg.query(
      `INSERT INTO reserved_names.names (kind, name, reason) VALUES ('username', 'support', 'staff')`
    );
    expect(await isReserved(pg, 'username', 'Support')).toBe(true);
    expect(await isReserved(pg, 'subdomain', 'support')).toBe(true);
    expect(await isReserved(pg, 'org_slug', 'support')).toBe(false);
  });

  it('picks up a newly added name and prefix at once', async () => {
    expect(await isReserved(pg, 'subdomain', 'www2')).toBe(false);
    expect(await isReserved(pg, 'subdomain', 'staff-east')).toBe(false);

    await pg.query(`
      INSERT INTO reserved_names.names (kind, name, is_prefix, reason) VALUES
        ('subdomain', 'www2', false, 'platform'),
        ('subdomain', 'staff-', true, 'platform')
    `);

    expect(await isReserved(pg, 'subdomain', 'www2')).toBe(true);
    expect(await isReserved(pg, 'subdomain', 'staff-east')).toBe(true);
    expect(await isReserved(pg, 'subdomain', 'staff')).toBe(false);
  });

  it('treats a NULL name as not reserved', async () => {
    expect(await isReserved(pg, 'subdomain', null as unknown as string)).toBe(false);
  });
});

describe('reserved_names.names', () => {
  it('rejects names that are not lowercase', async () => {
    await expect(
      pg.query(`INSERT INTO reserved_names.names (kind, name) VALUES ('subdomain', 'Shop')`)
    ).rejects.toThrow(/names_name_check/);
  });

  it('rejects an empty name', async () => {
    await expect(
      pg.query(`INSERT INTO reserved_names.names (kind, name) VALUES ('subdomain', '')`)
    ).rejects.toThrow(/names_name_check/);
  });

  it('rejects a malformed kind', async () => {
    await expect(
      pg.query(`INSERT INTO reserved_names.names (kind, name) VALUES ('Sub Domain', 'shop')`)
    ).rejects.toThrow(/names_kind_check/);
  });

  it('rejects a duplicate entry', async () => {
    await expect(
      pg.query(`INSERT INTO reserved_names.names (kind, name) VALUES ('subdomain', 'login')`)
    ).rejects.toThrow(/names_pkey/);
  });
});

describe.each(['anonymous', 'authenticated'])('as %s', (role) => {
  beforeEach(() => {
    db.setContext({ role });
  });

  it('can check a name and read the list', async () => {
    expect(await isReserved(db, 'subdomain', 'login')).toBe(true);
    const { count } = await db.one(
      `SELECT count(*)::int AS count FROM reserved_names.names WHERE kind = 'subdomain'`
    );
    expect(count).toBeGreaterThan(0);
  });

  it.each([
    [`INSERT INTO reserved_names.names (kind, name) VALUES ('subdomain', 'mine')`],
    [`UPDATE reserved_names.names SET reason = 'x' WHERE name = 'login'`],
    [`DELETE FROM reserved_names.names WHERE name = 'login'`]
  ])('cannot change the list: %s', async (sql) => {
    await expect(db.query(sql)).rejects.toThrow(/permission denied for table names/);
  });
});
