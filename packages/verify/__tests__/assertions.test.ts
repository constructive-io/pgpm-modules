import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

// The point of these assertions is that they can FAIL. Every describe below
// pairs the passing case with the drift a name-only verify_* check let through.
describe('catalog assertions', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());

    await pg.any(`CREATE SCHEMA assert_demo`);
    await pg.any(`
      CREATE FUNCTION assert_demo.greet (name text)
        RETURNS text AS $$ SELECT 'hi ' || name $$ LANGUAGE sql IMMUTABLE
    `);
    // Same name, different signature: the overload a name-only check confuses.
    await pg.any(`
      CREATE FUNCTION assert_demo.greet (name text, punct text)
        RETURNS text AS $$ SELECT 'hi ' || name || punct $$ LANGUAGE sql IMMUTABLE
    `);
    await pg.any(`
      CREATE FUNCTION assert_demo.elevated ()
        RETURNS void AS $$ BEGIN END $$ LANGUAGE plpgsql SECURITY DEFINER
    `);

    await pg.any(`CREATE TABLE assert_demo.users (id uuid PRIMARY KEY, email text)`);
    await pg.any(`CREATE UNIQUE INDEX users_email_key ON assert_demo.users (email)`);
    await pg.any(`CREATE INDEX users_email_idx ON assert_demo.users (email text_pattern_ops)`);
    await pg.any(`
      CREATE TABLE assert_demo.events (id uuid, at timestamptz)
        PARTITION BY RANGE (at)
    `);

    await pg.any(`
      CREATE VIEW assert_demo.user_emails WITH (security_invoker = true)
        AS SELECT email FROM assert_demo.users
    `);
    await pg.any(`
      CREATE VIEW assert_demo.definer_emails AS SELECT email FROM assert_demo.users
    `);
    await pg.any(`
      CREATE MATERIALIZED VIEW assert_demo.user_count
        AS SELECT count(*) FROM assert_demo.users
    `);

    await pg.any(`
      CREATE FUNCTION assert_demo.touch ()
        RETURNS trigger AS $$ BEGIN RETURN NEW; END $$ LANGUAGE plpgsql
    `);
    await pg.any(`
      CREATE FUNCTION assert_demo.other ()
        RETURNS trigger AS $$ BEGIN RETURN NEW; END $$ LANGUAGE plpgsql
    `);
    await pg.any(`
      CREATE TRIGGER stamps BEFORE INSERT OR UPDATE ON assert_demo.users
        FOR EACH ROW EXECUTE PROCEDURE assert_demo.touch()
    `);

    // A table-wide SELECT next to a column-scoped INSERT: the second is the
    // shape information_schema.role_table_grants cannot report.
    await pg.any(`CREATE ROLE grantee_demo`);
    await pg.any(`GRANT SELECT ON assert_demo.users TO grantee_demo`);
    await pg.any(`GRANT INSERT (email) ON assert_demo.users TO grantee_demo`);

    await pg.any(`CREATE DOMAIN assert_demo.email AS text CHECK (value ~ '@')`);
    await pg.any(`CREATE DOMAIN assert_demo.loose AS text`);
    await pg.any(`CREATE TYPE assert_demo.rgb AS ENUM ('r', 'g', 'b')`);

    await pg.any(`ALTER TABLE assert_demo.users ENABLE ROW LEVEL SECURITY`);
    await pg.any(`
      CREATE POLICY can_select ON assert_demo.users
        FOR SELECT USING (email IS NOT NULL)
    `);
    await pg.any(`
      CREATE POLICY block_all ON assert_demo.users
        AS RESTRICTIVE FOR ALL USING (email IS NOT NULL)
    `);
  });

  afterAll(async () => {
    await pg.any(`DROP SCHEMA IF EXISTS assert_demo CASCADE`);
    await pg.any(`DROP ROLE IF EXISTS grantee_demo`);
    await teardown();
  });

  const assertion = (sql: string) => pg.any(`SELECT ${sql}`);

  describe('assert_function', () => {
    it('passes for the exact signature', async () => {
      await expect(
        assertion(`assert_function('assert_demo.greet(text)'::regprocedure,
          'text'::regtype, _returns_set => false, _security_definer => false,
          _volatility => 'immutable')`)
      ).resolves.toBeDefined();
    });

    it('fails when the overload does not exist', async () => {
      await expect(
        assertion(`assert_function('assert_demo.greet(uuid)'::regprocedure)`)
      ).rejects.toThrow(/does not exist/);
    });

    it('fails on the wrong return type', async () => {
      await expect(
        assertion(
          `assert_function('assert_demo.greet(text)'::regprocedure, 'uuid'::regtype)`
        )
      ).rejects.toThrow('must return uuid, found text');
    });

    it('fails on an unintended SECURITY DEFINER', async () => {
      await expect(
        assertion(
          `assert_function('assert_demo.elevated()'::regprocedure, _security_definer => false)`
        )
      ).rejects.toThrow('must be SECURITY INVOKER');
    });

    it('fails on drifted volatility', async () => {
      await expect(
        assertion(
          `assert_function('assert_demo.greet(text)'::regprocedure, _volatility => 'stable')`
        )
      ).rejects.toThrow('must be STABLE, found IMMUTABLE');
    });
  });

  describe('assert_table', () => {
    it('passes for an ordinary table', async () => {
      await expect(
        assertion(`assert_table('assert_demo.users'::regclass)`)
      ).resolves.toBeDefined();
    });

    it('passes for a partitioned table', async () => {
      await expect(
        assertion(`assert_table('assert_demo.events'::regclass, _partitioned => true)`)
      ).resolves.toBeDefined();
    });

    it('fails when the table is really a view', async () => {
      await expect(
        assertion(`assert_table('assert_demo.user_emails'::regclass)`)
      ).rejects.toThrow('must be an ordinary table, found a view');
    });

    it('fails when a table stopped being partitioned', async () => {
      await expect(
        assertion(`assert_table('assert_demo.users'::regclass, _partitioned => true)`)
      ).rejects.toThrow('must be a partitioned table, found an ordinary table');
    });

    it('fails when the relation does not exist', async () => {
      await expect(
        assertion(`assert_table('assert_demo.nope'::regclass)`)
      ).rejects.toThrow(/does not exist/);
    });
  });

  describe('assert_view', () => {
    it('passes for a security_invoker view', async () => {
      await expect(
        assertion(
          `assert_view('assert_demo.user_emails'::regclass, _security_invoker => true)`
        )
      ).resolves.toBeDefined();
    });

    it('passes for a materialized view', async () => {
      await expect(
        assertion(`assert_view('assert_demo.user_count'::regclass, _materialized => true)`)
      ).resolves.toBeDefined();
    });

    it('fails when a view lost security_invoker', async () => {
      await expect(
        assertion(
          `assert_view('assert_demo.definer_emails'::regclass, _security_invoker => true)`
        )
      ).rejects.toThrow('must be a security_invoker view');
    });

    it('fails when an ordinary view is expected to be materialized', async () => {
      await expect(
        assertion(`assert_view('assert_demo.user_emails'::regclass, _materialized => true)`)
      ).rejects.toThrow('must be a materialized view, found a view');
    });
  });

  describe('assert_index', () => {
    it('passes for a unique index on the expected table', async () => {
      await expect(
        assertion(`assert_index('assert_demo.users_email_key'::regclass,
          'assert_demo.users'::regclass, _unique => true)`)
      ).resolves.toBeDefined();
    });

    it('fails when the index is not unique', async () => {
      await expect(
        assertion(`assert_index('assert_demo.users_email_idx'::regclass,
          'assert_demo.users'::regclass, _unique => true)`)
      ).rejects.toThrow('must be UNIQUE');
    });

    it('fails when the index covers another table', async () => {
      await expect(
        assertion(`assert_index('assert_demo.users_email_key'::regclass,
          'assert_demo.events'::regclass)`)
      ).rejects.toThrow('must index assert_demo.events');
    });
  });

  describe('assert_trigger', () => {
    // BEFORE (2) | INSERT (4) | UPDATE (16) | ROW (1)
    const tgtype = 2 | 4 | 16 | 1;

    it('passes for the deployed trigger', async () => {
      await expect(
        assertion(`assert_trigger('assert_demo.users'::regclass, 'stamps',
          'assert_demo.touch'::regproc, ${tgtype})`)
      ).resolves.toBeDefined();
    });

    it('fails when the trigger calls another function', async () => {
      await expect(
        assertion(`assert_trigger('assert_demo.users'::regclass, 'stamps',
          'assert_demo.other'::regproc)`)
      ).rejects.toThrow('must call assert_demo.other, found assert_demo.touch');
    });

    it('fails when the timing or events drifted', async () => {
      // AFTER (0) | DELETE (8) | ROW (1)
      await expect(
        assertion(
          `assert_trigger('assert_demo.users'::regclass, 'stamps', NULL, ${8 | 1})`
        )
      ).rejects.toThrow(
        'must be AFTER DELETE FOR EACH ROW, found BEFORE INSERT OR UPDATE FOR EACH ROW'
      );
    });

    it('fails when the trigger is attached to another table', async () => {
      await expect(
        assertion(`assert_trigger('assert_demo.events'::regclass, 'stamps')`)
      ).rejects.toThrow(/no data found|query returned no rows/i);
    });

    it('fails when the trigger is disabled', async () => {
      await pg.any(`ALTER TABLE assert_demo.users DISABLE TRIGGER stamps`);

      try {
        await expect(
          assertion(`assert_trigger('assert_demo.users'::regclass, 'stamps')`)
        ).rejects.toThrow('must be enabled');
      } finally {
        await pg.any(`ALTER TABLE assert_demo.users ENABLE TRIGGER stamps`);
      }
    });
  });

  describe('assert_policy', () => {
    it('passes for the deployed policy', async () => {
      await expect(
        assertion(`assert_policy('assert_demo.users'::regclass, 'can_select', 'SELECT',
          _permissive => true, _has_qual => true, _has_with_check => false)`)
      ).resolves.toBeDefined();
    });

    it('passes for a restrictive policy', async () => {
      await expect(
        assertion(`assert_policy('assert_demo.users'::regclass, 'block_all', 'ALL',
          _permissive => false)`)
      ).resolves.toBeDefined();
    });

    it('fails when the policy widened to another command', async () => {
      await expect(
        assertion(`assert_policy('assert_demo.users'::regclass, 'can_select', 'ALL')`)
      ).rejects.toThrow('must apply to ALL, found SELECT');
    });

    it('fails when a restrictive policy turned permissive', async () => {
      await expect(
        assertion(
          `assert_policy('assert_demo.users'::regclass, 'can_select', _permissive => false)`
        )
      ).rejects.toThrow('must be RESTRICTIVE');
    });

    it('fails when the USING clause was dropped', async () => {
      await expect(
        assertion(
          `assert_policy('assert_demo.users'::regclass, 'can_select', _has_with_check => true)`
        )
      ).rejects.toThrow('must carry a WITH CHECK clause');
    });
  });

  describe('assert_schema', () => {
    it('passes for a deployed schema', async () => {
      await expect(
        assertion(`assert_schema('assert_demo'::regnamespace)`)
      ).resolves.toBeDefined();
    });

    // The cast resolves the name, so the failure happens before the body runs —
    // which is the point: the schema is a reference, not a compared string.
    it('fails when the schema does not exist', async () => {
      await expect(
        assertion(`assert_schema('assert_nope'::regnamespace)`)
      ).rejects.toThrow(/does not exist/);
    });
  });

  describe('assert_table_grant', () => {
    it('passes for a table-wide grant', async () => {
      await expect(
        assertion(`assert_table_grant('assert_demo.users'::regclass, 'grantee_demo', 'SELECT')`)
      ).resolves.toBeDefined();
    });

    it('fails when the privilege was never granted', async () => {
      await expect(
        assertion(`assert_table_grant('assert_demo.users'::regclass, 'grantee_demo', 'DELETE')`)
      ).rejects.toThrow(/must hold DELETE/);
    });

    // The drift the old check could not see: GRANT INSERT (email) is invisible
    // to information_schema.role_table_grants, so verify_table_grant reported
    // every column-scoped grant as missing.
    it('passes for a column-scoped grant', async () => {
      await expect(
        assertion(
          `assert_table_grant('assert_demo.users'::regclass, 'grantee_demo', 'INSERT', ARRAY['email'])`
        )
      ).resolves.toBeDefined();
    });

    it('fails when only some of the columns are granted', async () => {
      await expect(
        assertion(
          `assert_table_grant('assert_demo.users'::regclass, 'grantee_demo', 'INSERT', ARRAY['email', 'id'])`
        )
      ).rejects.toThrow(/must hold INSERT .*\(id\)/);
    });

    // A revoke asserts absence, so a grant that comes back is caught too.
    it('asserts a privilege is absent', async () => {
      await expect(
        assertion(
          `assert_table_grant('assert_demo.users'::regclass, 'grantee_demo', 'DELETE', NULL, false)`
        )
      ).resolves.toBeDefined();

      await expect(
        assertion(
          `assert_table_grant('assert_demo.users'::regclass, 'grantee_demo', 'SELECT', NULL, false)`
        )
      ).rejects.toThrow(/must not hold SELECT/);
    });
  });

  describe('assert_table_security', () => {
    it('passes when row level security is enabled', async () => {
      await expect(
        assertion(`assert_table_security('assert_demo.users'::regclass)`)
      ).resolves.toBeDefined();
    });

    // A table that quietly loses RLS still exists, so the name-only check passed.
    it('fails when row level security is off', async () => {
      await expect(
        assertion(`assert_table_security('assert_demo.events'::regclass)`)
      ).rejects.toThrow(/must be enabled/);
    });

    it('fails when the owner is not forced through the policies', async () => {
      await expect(
        assertion(`assert_table_security('assert_demo.users'::regclass, true, true)`)
      ).rejects.toThrow(/must be forced/);
    });
  });

  describe('assert_function_grant', () => {
    it('passes for a granted function', async () => {
      await expect(
        assertion(
          `assert_function_grant('assert_demo.greet(text)'::regprocedure, 'grantee_demo')`
        )
      ).resolves.toBeDefined();
    });

    // The signature is resolved, so a grant checked against an overload that no
    // longer exists raises instead of reporting a missing privilege.
    it('fails when the signature does not exist', async () => {
      await expect(
        assertion(
          `assert_function_grant('assert_demo.greet(uuid)'::regprocedure, 'grantee_demo')`
        )
      ).rejects.toThrow(/does not exist/);
    });

    it('asserts a privilege is absent', async () => {
      await expect(
        assertion(
          `assert_function_grant('assert_demo.greet(text)'::regprocedure, 'grantee_demo', 'EXECUTE', false)`
        )
      ).rejects.toThrow(/must not hold EXECUTE/);
    });
  });

  describe('assert_domain', () => {
    it('passes for the base type and constraint count', async () => {
      await expect(
        assertion(
          `assert_domain('assert_demo.email'::regtype, 'text'::regtype, _constraints => 1)`
        )
      ).resolves.toBeDefined();
    });

    it('fails on the wrong base type', async () => {
      await expect(
        assertion(`assert_domain('assert_demo.email'::regtype, 'varchar'::regtype)`)
      ).rejects.toThrow(/must be built on character varying/);
    });

    // A domain whose CHECK was dropped still exists and still has its base type,
    // so it validates nothing while the name-only check keeps passing.
    it('fails when the domain carries no constraint', async () => {
      await expect(
        assertion(`assert_domain('assert_demo.loose'::regtype, _constraints => 1)`)
      ).rejects.toThrow(/must carry 1 constraint/);
    });

    it('fails when the name is a type rather than a domain', async () => {
      await expect(
        assertion(`assert_domain('assert_demo.rgb'::regtype)`)
      ).rejects.toThrow(/must be a domain/);
    });
  });

  describe('assert_type', () => {
    it('passes for a type of the expected kind', async () => {
      await expect(
        assertion(`assert_type('assert_demo.rgb'::regtype, 'e')`)
      ).resolves.toBeDefined();
    });

    it('fails on the wrong kind', async () => {
      await expect(
        assertion(`assert_type('assert_demo.rgb'::regtype, 'c')`)
      ).rejects.toThrow(/must be typtype c/);
    });

    it('fails when the name is a domain', async () => {
      await expect(
        assertion(`assert_type('assert_demo.email'::regtype)`)
      ).rejects.toThrow(/is a domain/);
    });
  });
});
