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

  it('matches the kind in any case', async () => {
    expect(await isReserved(pg, 'Subdomain', 'login')).toBe(true);
  });

  it('keeps kinds apart', async () => {
    expect(await isReserved(pg, 'username', 'login')).toBe(false);

    await pg.query(
      `INSERT INTO reserved_names.names (kind, name, reason) VALUES ('username', 'support', 'platform')`
    );
    expect(await isReserved(pg, 'username', 'Support')).toBe(true);
    expect(await isReserved(pg, 'subdomain', 'support')).toBe(true);
    expect(await isReserved(pg, 'slug', 'support')).toBe(false);
  });

  it('reserves every name ending in a suffix entry', async () => {
    await pg.query(`
      INSERT INTO reserved_names.names (kind, name, match, reason) VALUES
        ('domain', 'constructive.io', 'exact', 'brand'),
        ('domain', '.constructive.io', 'suffix', 'brand')
    `);
    expect(await isReserved(pg, 'domain', 'constructive.io')).toBe(true);
    expect(await isReserved(pg, 'domain', 'shop.Constructive.io')).toBe(true);
    expect(await isReserved(pg, 'domain', 'notconstructive.io')).toBe(false);
    expect(await isReserved(pg, 'domain', 'constructive.io.evil.com')).toBe(false);
  });

  it('picks up a newly added name and prefix at once', async () => {
    expect(await isReserved(pg, 'subdomain', 'www2')).toBe(false);
    expect(await isReserved(pg, 'subdomain', 'staff-east')).toBe(false);

    await pg.query(`
      INSERT INTO reserved_names.names (kind, name, match, reason) VALUES
        ('subdomain', 'www2', 'exact', 'platform'),
        ('subdomain', 'staff-', 'prefix', 'platform')
    `);

    expect(await isReserved(pg, 'subdomain', 'www2')).toBe(true);
    expect(await isReserved(pg, 'subdomain', 'staff-east')).toBe(true);
    expect(await isReserved(pg, 'subdomain', 'staff')).toBe(false);
  });

  it('treats a NULL name or kind as not reserved', async () => {
    expect(await isReserved(pg, 'subdomain', null as unknown as string)).toBe(false);
    expect(await isReserved(pg, null as unknown as string, 'login')).toBe(false);
  });
});

describe('reserved_names.reserved_by', () => {
  it('says which entries reserve a name and why', async () => {
    const rows = await pg.any(
      `SELECT name, match, reason FROM reserved_names.reserved_by('subdomain', 'xn--pple-43d')`
    );
    expect(rows).toEqual([{ name: 'xn--', match: 'prefix', reason: 'lookalike' }]);
  });

  it('returns nothing for a free name', async () => {
    const rows = await pg.any(`SELECT * FROM reserved_names.reserved_by('subdomain', 'mystore')`);
    expect(rows).toEqual([]);
  });
});

describe('the starter data', () => {
  it('has the four kinds and four reasons', async () => {
    const kinds = await pg.any(`SELECT kind FROM reserved_names.kinds ORDER BY kind`);
    expect(kinds.map((r) => r.kind)).toEqual(['domain', 'slug', 'subdomain', 'username']);
    const reasons = await pg.any(`SELECT reason FROM reserved_names.reasons ORDER BY reason`);
    expect(reasons.map((r) => r.reason)).toEqual(['abuse', 'brand', 'lookalike', 'platform']);
  });

  it('reserves no api- prefix', async () => {
    expect(await isReserved(pg, 'subdomain', 'api-docs')).toBe(false);
    expect(await isReserved(pg, 'subdomain', 'api')).toBe(true);
  });
});

describe('reserved_names.names', () => {
  it('rejects names that are not lowercase', async () => {
    await expect(
      pg.query(`INSERT INTO reserved_names.names (kind, name, reason) VALUES ('subdomain', 'Shop', 'platform')`)
    ).rejects.toThrow(/names_name_check/);
  });

  it('rejects an empty name', async () => {
    await expect(
      pg.query(`INSERT INTO reserved_names.names (kind, name, reason) VALUES ('subdomain', '', 'platform')`)
    ).rejects.toThrow(/names_name_check/);
  });

  it('rejects an unknown kind', async () => {
    await expect(
      pg.query(`INSERT INTO reserved_names.names (kind, name, reason) VALUES ('usrname', 'shop', 'platform')`)
    ).rejects.toThrow(/names_kind_fkey/);
  });

  it('rejects an unknown reason', async () => {
    await expect(
      pg.query(`INSERT INTO reserved_names.names (kind, name, reason) VALUES ('subdomain', 'shop', 'because')`)
    ).rejects.toThrow(/names_reason_fkey/);
  });

  it('requires a reason', async () => {
    await expect(
      pg.query(`INSERT INTO reserved_names.names (kind, name) VALUES ('subdomain', 'shop')`)
    ).rejects.toThrow(/null value in column "reason"/);
  });

  it('rejects an unknown match type', async () => {
    await expect(
      pg.query(`INSERT INTO reserved_names.names (kind, name, match, reason) VALUES ('subdomain', 'shop', 'regex', 'platform')`)
    ).rejects.toThrow(/names_match_check/);
  });

  it('rejects a duplicate entry', async () => {
    await expect(
      pg.query(`INSERT INTO reserved_names.names (kind, name, reason) VALUES ('subdomain', 'login', 'platform')`)
    ).rejects.toThrow(/names_pkey/);
  });

  it('allows the same name as exact and as a prefix', async () => {
    await pg.query(
      `INSERT INTO reserved_names.names (kind, name, match, reason) VALUES ('subdomain', 'login', 'prefix', 'platform')`
    );
    expect(await isReserved(pg, 'subdomain', 'login-now')).toBe(true);
  });
});

describe('reserved_names.kinds', () => {
  it('rejects a malformed kind', async () => {
    await expect(
      pg.query(`INSERT INTO reserved_names.kinds (kind, description) VALUES ('Sub Domain', 'x')`)
    ).rejects.toThrow(/kinds_kind_check/);
  });

  it('takes a new kind for later use', async () => {
    await pg.query(`INSERT INTO reserved_names.kinds (kind, description) VALUES ('team_slug', 'A team handle')`);
    await pg.query(
      `INSERT INTO reserved_names.names (kind, name, reason) VALUES ('team_slug', 'staff', 'platform')`
    );
    expect(await isReserved(pg, 'team_slug', 'staff')).toBe(true);
  });
});

describe.each(['anonymous', 'authenticated'])('as %s', (role) => {
  beforeEach(() => {
    db.setContext({ role });
  });

  it('can check a name and read the lists', async () => {
    expect(await isReserved(db, 'subdomain', 'login')).toBe(true);
    for (const table of ['names', 'kinds', 'reasons']) {
      const { count } = await db.one(`SELECT count(*)::int AS count FROM reserved_names.${table}`);
      expect(count).toBeGreaterThan(0);
    }
    const rows = await db.any(`SELECT reason FROM reserved_names.reserved_by('subdomain', 'login')`);
    expect(rows).toEqual([{ reason: 'platform' }]);
  });

  it.each([
    ['names', `INSERT INTO reserved_names.names (kind, name, reason) VALUES ('subdomain', 'mine', 'platform')`],
    ['names', `UPDATE reserved_names.names SET reason = 'brand' WHERE name = 'login'`],
    ['names', `DELETE FROM reserved_names.names WHERE name = 'login'`],
    ['kinds', `INSERT INTO reserved_names.kinds (kind, description) VALUES ('mine', 'x')`],
    ['kinds', `DELETE FROM reserved_names.kinds WHERE kind = 'slug'`],
    ['reasons', `INSERT INTO reserved_names.reasons (reason, description) VALUES ('mine', 'x')`],
    ['reasons', `DELETE FROM reserved_names.reasons WHERE reason = 'abuse'`]
  ])('cannot change %s: %s', async (table, sql) => {
    await expect(db.query(sql)).rejects.toThrow(new RegExp(`permission denied for table ${table}`));
  });
});
