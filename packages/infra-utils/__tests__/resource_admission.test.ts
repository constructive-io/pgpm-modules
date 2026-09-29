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

const ALLOWED = { allowed: true };

async function check(
  spec: unknown,
  kindPolicy: unknown,
  rules: unknown[] = [],
  scope = 'database',
  kind = 'Deployment'
) {
  return db.any(
    `SELECT infra_utils.check_resource_admission($1, 'my-slug', $2::jsonb, $3::jsonb, $4::jsonb, $5)`,
    [
      kind,
      JSON.stringify(spec),
      kindPolicy === null ? null : JSON.stringify(kindPolicy),
      JSON.stringify(rules),
      scope,
    ]
  );
}

describe('kind gate (fail closed)', () => {
  it('denies when no kind policy exists', async () => {
    await expect(check({}, null)).rejects.toThrow(/RESOURCE_KIND_NOT_ALLOWED/);
  });

  it('denies a disabled kind', async () => {
    await expect(check({}, { allowed: false })).rejects.toThrow(
      /RESOURCE_KIND_NOT_ALLOWED/
    );
  });

  it('denies when allowed is missing entirely', async () => {
    await expect(check({}, {})).rejects.toThrow(/RESOURCE_KIND_NOT_ALLOWED/);
  });

  it('allows an enabled kind with no rules', async () => {
    await expect(check({ image: 'nginx' }, ALLOWED)).resolves.toBeDefined();
  });

  it('denies a scope not in allowed_scopes', async () => {
    await expect(
      check({}, { allowed: true, allowed_scopes: ['platform'] }, [], 'database')
    ).rejects.toThrow(/RESOURCE_KIND_NOT_ALLOWED/);
  });

  it('allows a scope listed in allowed_scopes', async () => {
    await expect(
      check({}, { allowed: true, allowed_scopes: ['platform'] }, [], 'platform')
    ).resolves.toBeDefined();
  });
});

describe('banned_key', () => {
  const rule = {
    slug: 'no-host-network',
    rule_type: 'banned_key',
    match: { key: 'hostNetwork' },
  };

  it('denies the key at the top level', async () => {
    await expect(check({ hostNetwork: true }, ALLOWED, [rule])).rejects.toThrow(
      /RESOURCE_SPEC_NOT_ALLOWED/
    );
  });

  it('denies the key nested in objects and arrays', async () => {
    await expect(
      check({ template: { list: [{ hostNetwork: true }] } }, ALLOWED, [rule])
    ).rejects.toThrow(/RESOURCE_SPEC_NOT_ALLOWED/);
  });

  it('passes when the key is absent', async () => {
    await expect(check({ image: 'nginx' }, ALLOWED, [rule])).resolves.toBeDefined();
  });

  it('only applies to its kind when one is declared', async () => {
    const scoped = { ...rule, kind: 'Job' };
    await expect(
      check({ hostNetwork: true }, ALLOWED, [scoped], 'database', 'Deployment')
    ).resolves.toBeDefined();
    await expect(
      check({ hostNetwork: true }, ALLOWED, [scoped], 'database', 'Job')
    ).rejects.toThrow(/RESOURCE_SPEC_NOT_ALLOWED/);
  });

  const manifestPolicy = { allowed: true, spec_is_manifest: true };
  const manifestSpec = { documents: [{ kind: 'Prometheus', spec: { hostNetwork: true } }] };

  it('a kind whose spec is a manifest skips kind-agnostic rules', async () => {
    await expect(
      check(manifestSpec, manifestPolicy, [rule], 'platform', 'ManifestSet')
    ).resolves.toBeDefined();
  });

  it('a kind whose spec is a manifest still honours a rule naming it', async () => {
    await expect(
      check(manifestSpec, manifestPolicy, [{ ...rule, kind: 'ManifestSet' }], 'platform', 'ManifestSet')
    ).rejects.toThrow(/RESOURCE_SPEC_NOT_ALLOWED/);
  });

  it('a rule missing its match key denies instead of matching nothing', async () => {
    await expect(
      check({}, ALLOWED, [{ slug: 'broken', rule_type: 'banned_key', match: {} }])
    ).rejects.toThrow(/RESOURCE_ADMISSION_RULE_INVALID/);
  });
});

describe('banned_path', () => {
  const rule = {
    slug: 'no-host-path',
    rule_type: 'banned_path',
    match: { path: ['volumes', 'hostPath'] },
  };

  it('denies a value present at the path', async () => {
    await expect(
      check({ volumes: { hostPath: '/etc' } }, ALLOWED, [rule])
    ).rejects.toThrow(/RESOURCE_SPEC_NOT_ALLOWED/);
  });

  it('passes when the path is absent', async () => {
    await expect(check({ volumes: {} }, ALLOWED, [rule])).resolves.toBeDefined();
  });

  it('denies on a malformed path', async () => {
    await expect(
      check({}, ALLOWED, [{ slug: 'broken', rule_type: 'banned_path', match: {} }])
    ).rejects.toThrow(/RESOURCE_ADMISSION_RULE_INVALID/);
  });
});

describe('banned_env_value', () => {
  const rule = { slug: 'no-env-literals', rule_type: 'banned_env_value', match: {} };

  it('denies a literal env value', async () => {
    await expect(
      check({ env: [{ name: 'X', value: 'literal' }] }, ALLOWED, [rule])
    ).rejects.toThrow(/RESOURCE_SPEC_NOT_ALLOWED/);
  });

  it('passes env entries without literal values', async () => {
    await expect(
      check({ env: [{ name: 'X', from_secret: 'y' }] }, ALLOWED, [rule])
    ).resolves.toBeDefined();
  });
});

describe('allowed_value', () => {
  const rule = {
    slug: 'cluster-ip-only',
    rule_type: 'allowed_value',
    match: { path: ['type'], values: ['ClusterIP'] },
  };

  it('denies a value outside the allow-list', async () => {
    await expect(check({ type: 'LoadBalancer' }, ALLOWED, [rule])).rejects.toThrow(
      /RESOURCE_SPEC_NOT_ALLOWED/
    );
  });

  it('allows a listed value and an absent value', async () => {
    await expect(check({ type: 'ClusterIP' }, ALLOWED, [rule])).resolves.toBeDefined();
    await expect(check({}, ALLOWED, [rule])).resolves.toBeDefined();
  });

  it('denies on malformed match fields', async () => {
    await expect(
      check({}, ALLOWED, [
        { slug: 'broken', rule_type: 'allowed_value', match: { path: ['type'] } },
      ])
    ).rejects.toThrow(/RESOURCE_ADMISSION_RULE_INVALID/);
  });
});

describe('platform_only', () => {
  const rule = {
    slug: 'managed-platform-only',
    rule_type: 'platform_only',
    match: { path: ['mode'], value: 'managed' },
  };

  it('denies the reserved value outside platform scope', async () => {
    await expect(
      check({ mode: 'managed' }, ALLOWED, [rule], 'database')
    ).rejects.toThrow(/RESOURCE_SPEC_NOT_ALLOWED/);
  });

  it('allows the reserved value at platform scope and other values anywhere', async () => {
    await expect(
      check({ mode: 'managed' }, ALLOWED, [rule], 'platform')
    ).resolves.toBeDefined();
    await expect(
      check({ mode: 'external' }, ALLOWED, [rule], 'database')
    ).resolves.toBeDefined();
  });
});

describe('allowed_annotation_prefix', () => {
  const rule = {
    slug: 'cert-manager-annotations',
    rule_type: 'allowed_annotation_prefix',
    match: { prefix: 'cert-manager.io/' },
  };

  it('denies annotation keys outside the allowed prefixes', async () => {
    await expect(
      check({ annotations: { 'evil.io/inject': 'x' } }, ALLOWED, [rule])
    ).rejects.toThrow(/RESOURCE_SPEC_NOT_ALLOWED/);
  });

  it('allows annotation keys under an allowed prefix', async () => {
    await expect(
      check({ annotations: { 'cert-manager.io/cluster-issuer': 'x' } }, ALLOWED, [rule])
    ).resolves.toBeDefined();
  });

  it('leaves annotations unrestricted when no prefix rule matches the kind', async () => {
    await expect(
      check({ annotations: { 'anything.io/x': 'y' } }, ALLOWED, [])
    ).resolves.toBeDefined();
  });
});

describe('unknown rule types', () => {
  it('deny instead of silently passing', async () => {
    await expect(
      check({}, ALLOWED, [{ slug: 'typo', rule_type: 'baned_key', match: { key: 'x' } }])
    ).rejects.toThrow(/RESOURCE_ADMISSION_RULE_INVALID/);
  });
});
