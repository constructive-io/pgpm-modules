jest.setTimeout(30000);

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

async function merge(base: string | null, patch: string | null): Promise<unknown> {
  const [{ merged }] = await db.any<{ merged: unknown }>(
    'SELECT db_utils.jsonb_deep_merge($1::jsonb, $2::jsonb) AS merged',
    [base, patch]
  );
  return merged;
}

describe('db_utils.jsonb_deep_merge', () => {
  it('merges nested objects instead of replacing them wholesale', async () => {
    // This is the semantic `||` lacks and the reason the function exists: a
    // promoted parameter touching one leaf must not erase its siblings.
    expect(await merge('{"a":{"x":1,"y":2},"b":3}', '{"a":{"x":9},"c":4}')).toEqual({
      a: { x: 9, y: 2 },
      b: 3,
      c: 4,
    });
    expect(
      await merge(
        '{"resources":{"requests":{"cpu":"100m","memory":"1Gi"},"limits":{"cpu":"500m","memory":"4Gi"}}}',
        '{"resources":{"limits":{"memory":"8Gi"}}}'
      )
    ).toEqual({
      resources: {
        requests: { cpu: '100m', memory: '1Gi' },
        limits: { cpu: '500m', memory: '8Gi' },
      },
    });
  });

  it('recurses arbitrarily deep', async () => {
    expect(await merge('{"a":{"b":{"c":{"d":1,"e":2}}}}', '{"a":{"b":{"c":{"d":9}}}}')).toEqual({
      a: { b: { c: { d: 9, e: 2 } } },
    });
  });

  it('replaces scalars, arrays, and type mismatches wholesale', async () => {
    expect(await merge('{"a":1}', '{"a":2}')).toEqual({ a: 2 });
    expect(await merge('{"a":[1,2,3]}', '{"a":[4]}')).toEqual({ a: [4] });
    expect(await merge('{"a":{"x":1}}', '{"a":[1]}')).toEqual({ a: [1] });
    expect(await merge('{"a":[1]}', '{"a":{"x":1}}')).toEqual({ a: { x: 1 } });
    // Non-object roots: the patch simply wins.
    expect(await merge('5', '{"a":1}')).toEqual({ a: 1 });
    expect(await merge('{"a":1}', '7')).toEqual(7);
  });

  it('treats a JSON null in the patch as a deliberate null, not a deletion', async () => {
    expect(await merge('{"a":1,"b":2}', '{"a":null}')).toEqual({ a: null, b: 2 });
  });

  it('passes through SQL NULL on either side', async () => {
    expect(await merge(null, '{"a":1}')).toEqual({ a: 1 });
    expect(await merge('{"a":1}', null)).toEqual({ a: 1 });
    expect(await merge(null, null)).toBeNull();
  });

  it('returns an object when both sides are empty', async () => {
    expect(await merge('{}', '{}')).toEqual({});
  });
});
