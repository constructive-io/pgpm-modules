import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

const jwt = {
  user_id: 'b9d22af1-62c7-43a5-b8c4-50630bbd4962',
  database_id: '44744c94-93cf-425a-b524-ce6f1466e327',
  entity_id: 'f12f1f0d-6f62-4f4b-93f2-72ee5d2a5b8e',
  entity_type: 'org'
};

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());
});

afterAll(async () => {
  await teardown?.();
});

it('get values', async () => {
  await pg.any(`BEGIN`);
  await pg.any(
    `SELECT 
      set_config('jwt.claims.user_agent', $1, true),
      set_config('jwt.claims.ip_address', $2, true),
      set_config('jwt.claims.database_id', $3, true),
      set_config('jwt.claims.user_id', $4, true)
    `,
    [
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36',
      '127.0.0.1',
      jwt.database_id,
      jwt.user_id
    ]
  );

  const { user_agent } = await pg.one(
    `select jwt_public.current_user_agent() as user_agent`
  );
  const { ip_address } = await pg.one(
    `select jwt_public.current_ip_address() as ip_address`
  );
  const { database_id } = await pg.one(
    `select jwt_private.current_database_id() as database_id`
  );
  const { user_id } = await pg.one(
    `select jwt_public.current_user_id() as user_id`
  );
  await pg.any(`ROLLBACK`);

  expect({ user_agent }).toMatchSnapshot();
  expect({ ip_address }).toMatchSnapshot();
  expect({ database_id }).toMatchSnapshot();
  expect({ user_id }).toMatchSnapshot();
});

it('current_database_id returns the claim when it is set', async () => {
  await pg.any(`BEGIN`);
  await pg.any(`SELECT set_config('jwt.claims.database_id', $1, true)`, [
    jwt.database_id
  ]);
  const { database_id } = await pg.one(
    `select jwt_private.current_database_id() as database_id`
  );
  await pg.any(`ROLLBACK`);

  expect(database_id).toEqual(jwt.database_id);
});

it('require_database_id raises DATABASE_CLAIM_REQUIRED when the claim is absent', async () => {
  await pg.any(`BEGIN`);
  await expect(
    pg.one(`select jwt_private.require_database_id()`)
  ).rejects.toThrow('DATABASE_CLAIM_REQUIRED');
  await pg.any(`ROLLBACK`);
});

it('require_user_id raises ACTOR_CLAIM_REQUIRED when the claim is absent', async () => {
  await pg.any(`BEGIN`);
  await expect(
    pg.one(`select jwt_public.require_user_id()`)
  ).rejects.toThrow('ACTOR_CLAIM_REQUIRED');
  await pg.any(`ROLLBACK`);
});

it.each([
  ['unset', null],
  ['empty', ''],
  ['malformed', 'not-a-uuid']
])('current_database_id returns NULL for a %s claim', async (_label, value) => {
  await pg.any(`BEGIN`);
  if (value === null) {
    await pg.any(`RESET "jwt.claims.database_id"`);
  } else {
    await pg.any(
      `SELECT set_config('jwt.claims.database_id', $1, true)`,
      [value]
    );
  }
  const { database_id } = await pg.one(
    `select jwt_private.current_database_id() as database_id`
  );
  await pg.any(`ROLLBACK`);

  expect(database_id).toBeNull();
});

describe('entity claim readers', () => {
  it.each([
    ['unset', null, null],
    ['malformed', 'not-a-uuid', null],
    ['valid', jwt.entity_id, jwt.entity_id]
  ])('current_entity_id returns %s', async (_label, value, expected) => {
    await pg.any(`BEGIN`);
    if (value === null) {
      await pg.any(`RESET "jwt.claims.entity_id"`);
    } else {
      await pg.any(
        `SELECT set_config('jwt.claims.entity_id', $1, true)`,
        [value]
      );
    }
    const { entity_id } = await pg.one(
      `select jwt_private.current_entity_id() as entity_id`
    );
    await pg.any(`ROLLBACK`);

    expect(entity_id).toEqual(expected);
  });

  it('current_entity_id returns NULL for transaction-local residue after COMMIT', async () => {
    try {
      await pg.any(`BEGIN`);
      await pg.any(
        `SELECT set_config('jwt.claims.entity_id', $1, true)`,
        [jwt.entity_id]
      );
      await pg.any(`COMMIT`);

      const { entity_id } = await pg.one(
        `select jwt_private.current_entity_id() as entity_id`
      );
      expect(entity_id).toBeNull();
    } finally {
      await pg.any(`SELECT set_config('jwt.claims.entity_id', NULL, false)`);
    }
  });

  it.each([
    ['unset', null, null],
    ['valid', jwt.entity_type, jwt.entity_type]
  ])('current_entity_type returns %s', async (_label, value, expected) => {
    await pg.any(`BEGIN`);
    if (value === null) {
      await pg.any(`RESET "jwt.claims.entity_type"`);
    } else {
      await pg.any(
        `SELECT set_config('jwt.claims.entity_type', $1, true)`,
        [value]
      );
    }
    const { entity_type } = await pg.one(
      `select jwt_private.current_entity_type() as entity_type`
    );
    await pg.any(`ROLLBACK`);

    expect(entity_type).toEqual(expected);
  });

  it('current_entity_type returns NULL for transaction-local residue after COMMIT', async () => {
    try {
      await pg.any(`BEGIN`);
      await pg.any(
        `SELECT set_config('jwt.claims.entity_type', $1, true)`,
        [jwt.entity_type]
      );
      await pg.any(`COMMIT`);

      const { entity_type } = await pg.one(
        `select jwt_private.current_entity_type() as entity_type`
      );
      expect(entity_type).toBeNull();
    } finally {
      await pg.any(`SELECT set_config('jwt.claims.entity_type', NULL, false)`);
    }
  });

  it('require_database_id raises for a malformed claim', async () => {
    await pg.any(`BEGIN`);
    await pg.any(
      `SELECT set_config('jwt.claims.database_id', $1, true)`,
      ['not-a-uuid']
    );
    await expect(
      pg.one(`select jwt_private.require_database_id()`)
    ).rejects.toThrow('DATABASE_CLAIM_REQUIRED');
    await pg.any(`ROLLBACK`);
  });

  it('require_entity_id raises for an absent claim', async () => {
    await pg.any(`BEGIN`);
    await expect(
      pg.one(`select jwt_private.require_entity_id()`)
    ).rejects.toThrow('ENTITY_CLAIM_REQUIRED');
    await pg.any(`ROLLBACK`);
  });

  it('require_entity_type raises for an absent claim', async () => {
    await pg.any(`BEGIN`);
    await expect(
      pg.one(`select jwt_private.require_entity_type()`)
    ).rejects.toThrow('ENTITY_TYPE_CLAIM_REQUIRED');
    await pg.any(`ROLLBACK`);
  });
});

describe('attribution assertion', () => {
  it('raises on incomplete attribution by default', async () => {
    await pg.any(`BEGIN`);
    try {
      await pg.one(`select jwt_private.assert_attribution(NULL, NULL, NULL)`);
      throw new Error('assert_attribution did not raise');
    } catch (err) {
      expect(err).toMatchObject({ code: 'P0001' });
    } finally {
      await pg.any(`ROLLBACK`);
    }
  });

  it('warns and allows incomplete attribution when strict mode is disabled', async () => {
    const notices: Array<{ message?: string }> = [];
    const onNotice = (notice: { message?: string }) => notices.push(notice);
    pg.client.on('notice', onNotice);
    await pg.any(`BEGIN`);
    await pg.any(
      `SELECT set_config('jwt.strict_attribution', 'false', true)`
    );
    try {
      await pg.one(`select jwt_private.assert_attribution(NULL, NULL, NULL)`);
      await pg.one(
        `select jwt_private.assert_attribution(NULL, $1::uuid, NULL)`,
        [jwt.entity_id]
      );
      await pg.one(
        `select jwt_private.assert_attribution($1::uuid, NULL, $2::text)`,
        [jwt.user_id, jwt.entity_type]
      );
      await pg.any(`CREATE TEMP TABLE attribution_probe(value integer)`);
      await pg.any(`INSERT INTO attribution_probe VALUES (1)`);
      const [{ value }] = await pg.any(
        `SELECT value FROM attribution_probe`
      );
      expect(value).toBe(1);
    } finally {
      await pg.any(`ROLLBACK`);
      pg.client.off('notice', onNotice);
    }

    expect(notices.map(({ message }) => message)).toEqual(
      expect.arrayContaining([
        expect.stringContaining('ATTRIBUTION_REQUIRED'),
        expect.stringContaining('ENTITY_TYPE_REQUIRED'),
        expect.stringContaining('ENTITY_ID_REQUIRED'),
      ])
    );
  });

  it('raises when neither actor nor entity is present', async () => {
    await pg.any(`BEGIN`);
    await pg.any(`SELECT set_config('jwt.strict_attribution', 'true', true)`);
    try {
      await pg.one(`select jwt_private.assert_attribution(NULL, NULL, NULL)`);
      throw new Error('assert_attribution did not raise');
    } catch (err) {
      expect(err).toMatchObject({ code: 'P0001' });
      const detail = JSON.parse((err as { detail: string }).detail) as {
        code: string;
        context: {
          arguments: string[];
          claims: string[];
        };
      };
      expect(detail.code).toBe('ATTRIBUTION_REQUIRED');
      expect(detail.context).toEqual({
        arguments: ['actor_id', 'entity_id'],
        claims: ['jwt.claims.user_id', 'jwt.claims.entity_id'],
      });
    }
    await pg.any(`ROLLBACK`);
  });

  it('raises when an entity has no entity type', async () => {
    await pg.any(`BEGIN`);
    await pg.any(`SELECT set_config('jwt.strict_attribution', 'true', true)`);
    await expect(
      pg.one(
        `select jwt_private.assert_attribution(NULL, $1::uuid, NULL)`,
        [jwt.entity_id]
      )
    ).rejects.toThrow('ENTITY_TYPE_REQUIRED');
    await pg.any(`ROLLBACK`);
  });

  it('raises when an entity type has no entity', async () => {
    await pg.any(`BEGIN`);
    await pg.any(`SELECT set_config('jwt.strict_attribution', 'true', true)`);
    await expect(
      pg.one(
        `select jwt_private.assert_attribution($1::uuid, NULL, $2::text)`,
        [jwt.user_id, jwt.entity_type]
      )
    ).rejects.toThrow('ENTITY_ID_REQUIRED');
    await pg.any(`ROLLBACK`);
  });

  it('allows actor-only attribution', async () => {
    await expect(
      pg.one(`select jwt_private.assert_attribution($1::uuid, NULL, NULL)`, [
        jwt.user_id
      ])
    ).resolves.toBeDefined();
  });

  it('allows row-derived entity attribution with its type', async () => {
    await expect(
      pg.one(
        `select jwt_private.assert_attribution(NULL, $1::uuid, $2::text)`,
        [jwt.entity_id, jwt.entity_type]
      )
    ).resolves.toBeDefined();
  });
});
