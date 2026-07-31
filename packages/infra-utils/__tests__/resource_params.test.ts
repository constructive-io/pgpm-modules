jest.setTimeout(60000);

import { getConnections, PgTestClient } from 'pgsql-test';

let db: PgTestClient;
let teardown: () => Promise<void>;

beforeAll(async () => {
  ({ db, teardown } = await getConnections());
});

afterAll(async () => {
  await teardown();
});

beforeEach(async () => {
  await db.beforeEach();
});

afterEach(async () => {
  await db.afterEach();
});

/** The declared interface used by most cases: one int parameter driving two paths. */
const HEAP_SCHEMA = [
  {
    key: 'heap_mb',
    type: 'int',
    label: 'Heap size (MB)',
    default: 3072,
    min: 512,
    max: 16384,
    group: 'Resources',
    order: 10,
    bindings: [
      { path: 'settings.NODE_OPTIONS', template: '--max-old-space-size={{value}}' },
      { path: 'resources.limits.memory', scale: 1.34, round: 'ceil', unit: 'Mi' },
    ],
  },
  {
    key: 'replicas',
    type: 'int',
    default: 1,
    min: 0,
    max: 10,
    bindings: [{ path: 'replicas' }],
  },
];

/**
 * Run a statement expected to fail and assert its canonical error code, keeping
 * the surrounding test transaction usable (a raised error aborts it otherwise).
 */
async function expectError(
  run: () => Promise<unknown>,
  code: string | RegExp,
  label?: string
): Promise<void> {
  let message: string | undefined;
  try {
    await run();
  } catch (error) {
    message = (error as Error).message;
  }
  // A raised error aborts the enclosing test transaction, so restart it before
  // the next assertion in the same test.
  await db.afterEach();
  await db.beforeEach();
  if (message === undefined) {
    throw new Error(
      `expected ${label ?? 'the statement'} to fail with ${String(code)}`
    );
  }
  expect(message).toMatch(code);
}

async function compile(
  baseSpec: unknown,
  schema: unknown,
  params: unknown,
  slug = 'graphql-private',
  bundleSchemas: unknown = null
): Promise<Record<string, unknown>> {
  const [{ spec }] = await db.any<{ spec: Record<string, unknown> }>(
    'SELECT infra_utils.compile_resource_spec($1::jsonb, $2::jsonb, $3::jsonb, $4, $5::jsonb) AS spec',
    [
      JSON.stringify(baseSpec),
      JSON.stringify(schema),
      JSON.stringify(params),
      slug,
      bundleSchemas === null ? null : JSON.stringify(bundleSchemas),
    ]
  );
  return spec;
}

async function validateSchema(schema: unknown): Promise<void> {
  await db.any('SELECT infra_utils.validate_params_schema($1::jsonb)', [JSON.stringify(schema)]);
}

async function validateBundle(schemas: unknown, params: unknown): Promise<void> {
  await db.any('SELECT infra_utils.validate_bundle_params($1::jsonb, $2::jsonb)', [
    JSON.stringify(schemas),
    JSON.stringify(params),
  ]);
}

async function changeSchema(oldSchema: unknown, newSchema: unknown): Promise<void> {
  await db.any('SELECT infra_utils.validate_params_schema_change($1::jsonb, $2::jsonb)', [
    JSON.stringify(oldSchema),
    JSON.stringify(newSchema),
  ]);
}

describe('infra_utils.quantity_to_numeric', () => {
  it('parses the Kubernetes quantity notation and rejects everything else', async () => {
    const [row] = await db.any<Record<string, string | null>>(`
      SELECT infra_utils.quantity_to_numeric('4Gi')  AS gi,
             infra_utils.quantity_to_numeric('512Mi') AS mi,
             infra_utils.quantity_to_numeric('500m')  AS milli,
             infra_utils.quantity_to_numeric('2')     AS plain,
             infra_utils.quantity_to_numeric('1G')    AS decimal_g,
             infra_utils.quantity_to_numeric('4GB')   AS bogus_suffix,
             infra_utils.quantity_to_numeric('big')   AS not_a_number
    `);
    expect(Number(row.gi)).toBe(4 * 1024 ** 3);
    expect(Number(row.mi)).toBe(512 * 1024 ** 2);
    expect(Number(row.milli)).toBe(0.5);
    expect(Number(row.plain)).toBe(2);
    expect(Number(row.decimal_g)).toBe(1e9);
    expect(row.bogus_suffix).toBeNull();
    expect(row.not_a_number).toBeNull();
  });
});

describe('infra_utils.compile_resource_spec — declared interface', () => {
  it('lands each parameter at its declared paths and derives coherent values', async () => {
    // heap_mb drives BOTH the Node flag and the container memory limit, so a
    // heap larger than its own limit is not expressible.
    const spec = await compile(
      {
        replicas: 1,
        resources: { requests: { cpu: '100m', memory: '1Gi' }, limits: { cpu: '500m' } },
        settings: { NODE_ENV: 'development', SERVER_HOST: '0.0.0.0' },
      },
      HEAP_SCHEMA,
      { heap_mb: 6144 }
    );
    expect(spec).toEqual({
      replicas: 1,
      resources: {
        requests: { cpu: '100m', memory: '1Gi' },
        limits: { cpu: '500m', memory: '8233Mi' },
      },
      settings: {
        NODE_ENV: 'development',
        SERVER_HOST: '0.0.0.0',
        NODE_OPTIONS: '--max-old-space-size=6144',
      },
    });
  });

  it('applies declared defaults when a parameter is not supplied', async () => {
    const spec = await compile({}, HEAP_SCHEMA, {});
    expect(spec).toEqual({
      replicas: 1,
      resources: { limits: { memory: '4117Mi' } },
      settings: { NODE_OPTIONS: '--max-old-space-size=3072' },
    });
  });

  it('lets a member override a bundle-wide value', async () => {
    const params = { heap_mb: 1024, members: { 'graphql-private': { heap_mb: 8192 } } };
    const priv = await compile({}, HEAP_SCHEMA, params, 'graphql-private');
    const pub = await compile({}, HEAP_SCHEMA, params, 'graphql-public');
    expect(priv.settings).toEqual({ NODE_OPTIONS: '--max-old-space-size=8192' });
    expect(pub.settings).toEqual({ NODE_OPTIONS: '--max-old-space-size=1024' });
  });

  it('writes nothing for a parameter with neither value nor default', async () => {
    const schema = [{ key: 'image', type: 'text', bindings: [{ path: 'image' }] }];
    const spec = await compile({ image: 'from-definition' }, schema, {});
    expect(spec).toEqual({ image: 'from-definition' });
  });

  it('rejects a value of the wrong type', async () => {
    await expectError(
      () => compile({}, HEAP_SCHEMA, { heap_mb: '6144' }),
      'RESOURCE_PARAM_INVALID'
    );
    await expectError(() => compile({}, HEAP_SCHEMA, { heap_mb: 1.5 }), 'RESOURCE_PARAM_INVALID');
  });

  it('rejects values outside the declared range', async () => {
    await expectError(() => compile({}, HEAP_SCHEMA, { heap_mb: 128 }), 'RESOURCE_PARAM_INVALID');
    await expectError(() => compile({}, HEAP_SCHEMA, { heap_mb: 99999 }), 'RESOURCE_PARAM_INVALID');
  });

  it('validates enum options and Kubernetes quantities', async () => {
    const schema = [
      {
        key: 'node_env',
        type: 'enum',
        options: ['development', 'production'],
        bindings: [{ path: 'settings.NODE_ENV' }],
      },
      {
        key: 'memory_limit',
        type: 'quantity',
        min: '256Mi',
        bindings: [{ path: 'resources.limits.memory' }],
      },
    ];
    expect(
      await compile({}, schema, { node_env: 'production', memory_limit: '2Gi' })
    ).toEqual({
      settings: { NODE_ENV: 'production' },
      resources: { limits: { memory: '2Gi' } },
    });
    await expectError(() => compile({}, schema, { node_env: 'staging' }), 'RESOURCE_PARAM_INVALID');
    await expectError(
      () => compile({}, schema, { memory_limit: '4GB' }),
      'RESOURCE_PARAM_INVALID'
    );
    await expectError(
      () => compile({}, schema, { memory_limit: '128Mi' }),
      'RESOURCE_PARAM_INVALID'
    );
  });

  it('rejects a required parameter that was not supplied', async () => {
    const schema = [
      { key: 'image', type: 'text', required: true, bindings: [{ path: 'image' }] },
    ];
    await expectError(() => compile({}, schema, {}), 'RESOURCE_PARAM_REQUIRED');
    expect(await compile({}, schema, { image: 'repo/img:1' })).toEqual({ image: 'repo/img:1' });
  });

  it('rejects a key the member does not declare', async () => {
    await expectError(
      () => compile({}, HEAP_SCHEMA, { members: { 'graphql-private': { heep_mb: 1024 } } }),
      'RESOURCE_PARAM_UNKNOWN'
    );
  });

  it('keeps its default spec when a sibling member owns the parameters', async () => {
    // A Service member of a typed bundle declares nothing. The params object is
    // then a set of DECLARED parameters (heap_mb, node_env, ...) belonging to the
    // Deployment members, not raw spec fields, so it must not land here.
    const bundle = [
      { slug: 'graphql-private', params_schema: HEAP_SCHEMA },
      { slug: 'graphql-private-svc', params_schema: [] as unknown[] },
    ];
    expect(
      await compile(
        { ports: [{ port: 3000, targetPort: 3000 }] },
        [],
        { heap_mb: 6144 },
        'graphql-private-svc',
        bundle
      )
    ).toEqual({ ports: [{ port: 3000, targetPort: 3000 }] });
  });

  it('still deep-merges raw params when NO member of the bundle declares an interface', async () => {
    const bundle = [
      { slug: 'a', params_schema: [] as unknown[] },
      { slug: 'b', params_schema: [] as unknown[] },
    ];
    expect(await compile({ replicas: 1 }, [], { replicas: 4 }, 'a', bundle)).toEqual({
      replicas: 4,
    });
  });

  it('ignores an unrelated member overlay', async () => {
    const spec = await compile(
      {},
      HEAP_SCHEMA,
      { members: { 'graphql-public': { heap_mb: 9000 } } },
      'graphql-private'
    );
    expect(spec.settings).toEqual({ NODE_OPTIONS: '--max-old-space-size=3072' });
  });
});

describe('infra_utils.compile_resource_spec — no declared interface', () => {
  it('falls back to the historical deep merge', async () => {
    const base = { replicas: 1, resources: { limits: { cpu: '500m', memory: '4Gi' } } };
    const emptyInterfaces: unknown[] = [null, []];
    for (const schema of emptyInterfaces) {
      expect(
        await compile(base, schema, {
          resources: { limits: { memory: '8Gi' } },
          members: { 'graphql-private': { replicas: 3 } },
        })
      ).toEqual({
        replicas: 3,
        resources: { limits: { cpu: '500m', memory: '8Gi' } },
      });
    }
  });
});

describe('infra_utils.validate_params_schema', () => {
  it('accepts a well-formed interface', async () => {
    await validateSchema(HEAP_SCHEMA);
    await validateSchema([]);
    await validateSchema(null);
  });

  it('rejects malformed declarations', async () => {
    const cases: unknown[] = [
      { key: 'heap_mb' }, // not an array
      [{ key: 'Heap MB', type: 'int', bindings: [{ path: 'a' }] }], // bad key
      [{ key: 'members', type: 'int', bindings: [{ path: 'a' }] }], // reserved key
      [{ key: 'heap_mb', type: 'float', bindings: [{ path: 'a' }] }], // unknown type
      [{ key: 'heap_mb', type: 'int' }], // no bindings
      [{ key: 'heap_mb', type: 'int', bindings: [] }], // empty bindings
      [{ key: 'mode', type: 'enum', bindings: [{ path: 'a' }] }], // enum without options
      [{ key: 'mode', type: 'text', options: ['a'], bindings: [{ path: 'a' }] }], // options on non-enum
      [{ key: 'name', type: 'text', min: 1, bindings: [{ path: 'a' }] }], // min on text
      [{ key: 'x', type: 'int', required: true, default: 1, bindings: [{ path: 'a' }] }],
      [{ key: 'x', type: 'int', bindings: [{ path: 'a..b' }] }], // empty path segment
      [{ key: 'x', type: 'int', bindings: [{ path: 'a', template: 'no interpolation' }] }],
      [{ key: 'x', type: 'int', bindings: [{ path: 'a', template: '{{value}}', scale: 2 }] }],
      [{ key: 'x', type: 'quantity', bindings: [{ path: 'a', scale: 2 }] }], // scale on quantity
      [{ key: 'x', type: 'int', bindings: [{ path: 'a', scale: 2, round: 'up' }] }],
      [{ key: 'x', type: 'int', default: 'big', bindings: [{ path: 'a' }] }], // default type
      [
        { key: 'x', type: 'int', bindings: [{ path: 'a' }] },
        { key: 'x', type: 'text', bindings: [{ path: 'b' }] },
      ], // duplicate key
    ];
    for (const [index, schema] of cases.entries()) {
      await expectError(
        () => validateSchema(schema),
        /RESOURCE_PARAM/,
        `malformed case ${index}: ${JSON.stringify(schema)}`
      );
    }
  });
});

describe('infra_utils.validate_params_schema_change', () => {
  it('rejects retyping a declared key and allows every other evolution', async () => {
    const before = [{ key: 'heap_mb', type: 'int', bindings: [{ path: 'a' }] }];
    const retyped = [{ key: 'heap_mb', type: 'quantity', bindings: [{ path: 'a' }] }];
    const extended = [
      ...before,
      { key: 'replicas', type: 'int', bindings: [{ path: 'replicas' }] },
    ];
    await expectError(() => changeSchema(before, retyped), 'RESOURCE_PARAM_RETYPED');
    await changeSchema(before, extended);
    await changeSchema(before, []);
  });
});

describe('infra_utils.validate_bundle_params', () => {
  const schemas = [
    { slug: 'graphql-private', params_schema: HEAP_SCHEMA },
    {
      slug: 'graphql-private-svc',
      params_schema: [{ key: 'port', type: 'int', bindings: [{ path: 'ports.0.port' }] }],
    },
  ];

  it('accepts keys declared by any member and member-addressed keys it declares', async () => {
    await validateBundle(schemas, {
      heap_mb: 4096,
      port: 5678,
      members: { 'graphql-private': { replicas: 2 } },
    });
  });

  it('rejects a key no member declares', async () => {
    await expectError(
      () => validateBundle(schemas, { heep_mb: 4096 }),
      'RESOURCE_PARAM_UNKNOWN'
    );
  });

  it('rejects an unknown member and a key that member does not declare', async () => {
    await expectError(
      () => validateBundle(schemas, { members: { 'graphql-nope': { heap_mb: 1 } } }),
      'RESOURCE_PARAM_UNKNOWN'
    );
    await expectError(
      () => validateBundle(schemas, { members: { 'graphql-private-svc': { heap_mb: 1 } } }),
      'RESOURCE_PARAM_UNKNOWN'
    );
  });

  it('leaves bundles that declare nothing unconstrained', async () => {
    await validateBundle([{ slug: 'legacy', params_schema: [] }], { anything: { at: 'all' } });
  });
});

describe('infra_utils.bundle_param_interface', () => {
  it('merges members into one public interface and records who consumes each key', async () => {
    const [{ iface }] = await db.any<{ iface: Array<Record<string, unknown>> }>(
      'SELECT infra_utils.bundle_param_interface($1::jsonb) AS iface',
      [
        JSON.stringify([
          {
            slug: 'graphql-public',
            params_schema: [
              { key: 'replicas', type: 'int', default: 1, order: 1, bindings: [{ path: 'replicas' }] },
            ],
          },
          {
            slug: 'graphql-private',
            params_schema: [
              { key: 'replicas', type: 'int', default: 1, order: 1, bindings: [{ path: 'replicas' }] },
              { key: 'heap_mb', type: 'int', default: 3072, order: 2, bindings: [{ path: 'settings.NODE_OPTIONS', template: '{{value}}' }] },
            ],
          },
        ]),
      ]
    );
    expect(iface.map((p) => p.key)).toEqual(['replicas', 'heap_mb']);
    expect(iface[0].members).toEqual(
      expect.arrayContaining(['graphql-public', 'graphql-private'])
    );
    expect(iface[1].members).toEqual(['graphql-private']);
  });

  it('rejects members that declare the same key with different types', async () => {
    await expectError(
      () =>
        db.any('SELECT infra_utils.bundle_param_interface($1::jsonb)', [
          JSON.stringify([
            { slug: 'a', params_schema: [{ key: 'size', type: 'int', bindings: [{ path: 'x' }] }] },
            {
              slug: 'b',
              params_schema: [{ key: 'size', type: 'quantity', bindings: [{ path: 'x' }] }],
            },
          ]),
        ]),
      'RESOURCE_PARAM_CONFLICT'
    );
  });
});
