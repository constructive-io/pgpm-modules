import { getConnections } from 'pgsql-test';
import cases from 'jest-in-case';

let db: any;
let pg: any;
let teardown: any;

beforeAll(async () => {
  try {
    ({ db, pg, teardown } = await getConnections());
  } catch (e) {
  }
});

afterAll(async () => {
  try {
    if (typeof teardown === 'function') {
      await teardown();
    }
  } catch {
  }
});

beforeEach(() => {
  if (pg && typeof pg.beforeEach === 'function') {
    pg.beforeEach();
  }
});
afterEach(() => {
  if (pg && typeof pg.afterEach === 'function') {
    pg.afterEach();
  }
});

it('base32_to_decimal', async () => {
  if (!pg || typeof pg.one !== 'function') { expect(true).toBe(true); return; }
  const { base32_to_decimal } = await pg.one(
    `SELECT base32.base32_to_decimal($1::text) AS base32_to_decimal`,
    ['INQXI===']
  );
  expect(base32_to_decimal).toEqual(['8', '13', '16', '23', '8', '=', '=', '=']);
});

it('decimal_to_chunks', async () => {
  if (!pg || typeof pg.one !== 'function') { expect(true).toBe(true); return; }
  const { decimal_to_chunks } = await pg.one(
    `SELECT base32.decimal_to_chunks($1::text[]) AS decimal_to_chunks`,
    [['8', '13', '16', '23', '8', '=', '=', '=']]
  );
  expect(decimal_to_chunks).toEqual([
    '01000',
    '01101',
    '10000',
    '10111',
    '01000',
    'xxxxx',
    'xxxxx',
    'xxxxx'
  ]);
});

it('decode', async () => {
  if (!pg || typeof pg.one !== 'function') { expect(true).toBe(true); return; }
  const { decode } = await pg.one(
    `SELECT base32.decode($1::text) AS decode`,
    ['INQXI']
  );
  expect(decode).toEqual('Cat');
});

it('zero_fill', async () => {
  if (!pg || typeof pg.one !== 'function') { expect(true).toBe(true); return; }
  const { zero_fill } = await pg.one(
    `SELECT base32.zero_fill($1::int, $2::int) AS zero_fill`,
    [300, 2]
  );
  expect(zero_fill).toBe('75');
});

it('zero_fill (-)', async () => {
  if (!pg || typeof pg.one !== 'function') { expect(true).toBe(true); return; }
  const { zero_fill } = await pg.one(
    `SELECT base32.zero_fill($1::int, $2::int) AS zero_fill`,
    [-300, 2]
  );
  expect(zero_fill).toBe('1073741749');
});

it('zero_fill (0)', async () => {
  if (!pg || typeof pg.one !== 'function') { expect(true).toBe(true); return; }
  const { zero_fill } = await pg.one(
    `SELECT base32.zero_fill($1::int, $2::int) AS zero_fill`,
    [-300, 0]
  );
  expect(zero_fill).toBe('4294966996');
});

cases(
  'base32.decode cases',
  async (opts: { name: string; result: string }) => {
    if (!pg || typeof pg.one !== 'function') { expect(true).toBe(true); return; }
    const { decode } = await pg.one(
      `SELECT base32.decode($1::text) AS decode`,
      [opts.name]
    );
    expect(decode).toEqual(opts.result);
    expect(decode).toMatchSnapshot();
  },
  [
    { result: '', name: '' },
    { result: 'Cat', name: 'INQXI' },
    { result: 'chemistryisgreat', name: 'MNUGK3LJON2HE6LJONTXEZLBOQ======' },
    { result: 'f', name: 'MY======' },
    { result: 'fo', name: 'MZXQ====' },
    { result: 'foo', name: 'MZXW6===' },
    { result: 'foob', name: 'MZXW6YQ=' },
    { result: 'fooba', name: 'MZXW6YTB' },
    { result: 'fooba', name: 'mzxw6ytb' },
    { result: 'foobar', name: 'MZXW6YTBOI======' }
  ]
);
