import { getConnections, PgTestClient } from 'pgsql-test';
import cases from 'jest-in-case';

let pg: PgTestClient;
let teardown:  () => Promise<void>;

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());
});

afterAll(async () => {
  await teardown();
});


it('totp.generate + totp.verify basic', async () => {
  const { generate } = await pg.one(
    `SELECT totp.generate($1::text) AS generate`,
    ['secret']
  );
  const { verify } = await pg.one(
    `SELECT totp.verify($1::text, $2::text) AS verify`,
    ['secret', generate]
  );
  expect(typeof generate).toBe('string');
  expect(verify).toBe(true);
});

it('totp.generate handles keys whose bytes contain a NUL', async () => {
  // decodes to five 0x00 bytes; chr(0) would raise "null character not permitted"
  const { generate } = await pg.one(
    `SELECT totp.generate($1::text) AS generate`,
    ['AAAAAAAA']
  );
  expect(generate).toMatch(/^\d{6}$/);
});

cases(
  'totp.base32_to_hex cases',
  async (opts: { name: string; result: string }) => {
    const { base32_to_hex } = await pg.one(
      `SELECT totp.base32_to_hex($1::text) AS base32_to_hex`,
      [opts.name]
    );
    expect(base32_to_hex).toEqual(opts.result);
  },
  [
    { result: '', name: '' },
    { result: '666f6f626172', name: 'MZXW6YTBOI======' },
    { result: '666f6f626172', name: 'mzxw6ytboi' },
    { result: '0000000000', name: 'AAAAAAAA' },
    { result: '00ff00ff00', name: 'AD7QB7YA' },
    { result: '48656c6c6f21deadbeef', name: 'JBSWY3DPEHPK3PXP' }
  ]
);
