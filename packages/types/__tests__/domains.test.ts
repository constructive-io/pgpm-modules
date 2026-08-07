import { getConnections, PgTestClient } from 'pgsql-test';

// Validation rules:
// - url: lenient regex ^https?://[^\s]+$ (must start with http/https, no whitespace, paths allowed)
// - origin: strict regex ^https?://[^/\s]+$ (protocol + host only, no paths for CORS security)
// - attachment: lenient regex ^https?://[^\s]+$ (same as url)
// - hostname: no whitespace (^[^\s]+$)
// - email: must contain @ (value ~ '@')
// - image: jsonb object requiring 'url' OR 'id' OR 'key', with type validation, optional bucket/provider/mime/versions (versions is array)
// - upload: jsonb object requiring 'url' OR 'id' OR 'key', with type validation on all fields, optional bucket/provider/mime
// both also carry the files-row projection keys: bucket_id (uuid string), size (number), filename (string)

const fileId = '0d1e3d64-1e2a-4c7f-9c3a-6f7f9f2b1c44';
const bucketId = '9a7f1c2e-4b6d-4a11-8f30-2c5d7e9a0b13';

const validUrls = [
  'http://foo.com/blah_blah',
  'http://foo.com/blah_blah/',
  'http://foo.com/blah_blah_(wikipedia)',
  'http://www.example.com/wpstyle/?p=364',
  'https://www.example.com/foo/?bar=baz&inga=42&quux',
  'http://foo.com/blah_(wikipedia)#cite-1',
  'http://foo.com/(something)?after=parens',
  'http://code.google.com/events/#&product=browser',
  'http://j.mp',
  'http://foo.bar/?q=Test%20URL-encoded%20stuff',
  'http://1337.net',
  'http://a.b-c.de',
  'https://foo_bar.example.com/'
];

const invalidUrls = [
  'foo.com',
  'ftp://foo.bar/',
  'not-a-url',
  'random text with spaces',
  '//missing-protocol.com'
];

// Valid origins: protocol + host only (no paths)
const validOrigins = [
  'http://example.com',
  'https://example.com',
  'http://localhost:3000',
  'https://api.example.com:8080',
  'http://192.168.1.1',
  'https://foo_bar.example.com'
];

// Invalid origins: paths, query strings, fragments, or non-http protocols
const invalidOrigins = [
  'https://example.com/',
  'https://example.com/path',
  'https://example.com/malicious/path',
  'https://example.com?query=1',
  'https://example.com#fragment',
  'ftp://example.com',
  'foo.com',
  'not-an-origin'
];

const validImages = [
  { url: 'http://www.foo.bar/some.jpg' },
  { url: 'https://foo.bar/some.PNG' },
  { url: 'https://example.com/path/to/image.png' },
  { url: 'https://example.com/image.png', bucket: 'my-bucket' },
  { url: 'https://example.com/image.png', provider: 's3' },
  { url: 'https://example.com/image.png', mime: 'image/png' },
  { url: 'https://example.com/image.png', bucket: 'my-bucket', provider: 's3', mime: 'image/jpeg' },
  { id: 'some-image-id' },
  { key: 'some-image-key' },
  { id: 'private-image', bucket: 'my-bucket', provider: 's3' },
  { url: 'https://example.com/image.png', versions: ['thumb', 'medium', 'large'] },
  { id: 'image-with-versions', versions: [{ size: 'thumb' }, { size: 'large' }] },
  { id: fileId, key: 'abc', mime: 'image/png', bucket_id: bucketId, size: 12345, filename: 'hero.png' },
  { id: fileId, bucket_id: bucketId.toUpperCase() }
];

const invalidImages = [
  { notUrl: 'missing required keys' },
  { mime: 'only mime, no url/id/key' },
  { url: 'not-a-valid-url' },
  { url: 'ftp://wrong-protocol.com/image.png' },
  { id: 123 },
  { key: true },
  { url: 'https://example.com/image.png', bucket: 123 },
  { url: 'https://example.com/image.png', provider: true },
  { url: 'https://example.com/image.png', mime: ['array'] },
  { url: 'https://example.com/image.png', versions: 'not-an-array' },
  { id: fileId, bucket_id: 'not-a-uuid' },
  { id: fileId, bucket_id: bucketId.replace(/-/g, '') },
  { id: fileId, size: '12345' },
  { id: fileId, filename: 42 },
  'not-an-object',
  ['array-not-object']
];

const validUploads = [
  { url: 'http://www.foo.bar/some.jpg' },
  { url: 'https://foo.bar/some.PNG' },
  { id: 'some-id' },
  { key: 'some-key' },
  { url: 'https://example.com/file.pdf', id: 'with-id' },
  { id: 'some-id', bucket: 'my-bucket', provider: 's3' },
  { key: 'some-key', mime: 'application/pdf' },
  { url: 'https://example.com/file.pdf', bucket: 'bucket', provider: 'gcs', mime: 'application/pdf' },
  { id: fileId, key: 'abc', mime: 'application/pdf', bucket_id: bucketId, size: 12345, filename: 'contract.pdf' },
  { id: fileId, bucket_id: bucketId.toUpperCase() }
];

const invalidUploads = [
  { notUrl: 'missing required keys' },
  { mime: 'only mime, no url/id/key' },
  { url: 'not-a-valid-url' },
  { url: 'ftp://wrong-protocol.com/file.pdf' },
  { id: 123 },
  { key: true },
  { url: 'https://example.com/file.pdf', bucket: 123 },
  { url: 'https://example.com/file.pdf', provider: ['array'] },
  { id: 'some-id', mime: { nested: 'object' } },
  { id: fileId, bucket_id: 'not-a-uuid' },
  { id: fileId, bucket_id: bucketId.replace(/-/g, '') },
  { id: fileId, size: '12345' },
  { id: fileId, filename: 42 },
  'not-an-object',
  ['array-not-object']
];

let pg: PgTestClient;
let teardown:  () => Promise<void>;

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());
});

beforeAll(async () => {
  await pg.any(`
CREATE TABLE customers (
  id serial,
  url url,
  origin origin,
  image image,
  attachment attachment,
  domain hostname,
  email email,
  upload upload
);
  `);
});

beforeEach(async () => {
  await pg.beforeEach();
});

afterEach(async () => {
  await pg.afterEach();
});

afterAll(async () => {
  await teardown();
});

describe('types', () => {
  describe('url domain (lenient regex: ^https?://[^\\s]+$)', () => {
    it('accepts valid URLs', async () => {
      for (const value of validUrls) {
        await pg.any(`INSERT INTO customers (url) VALUES ($1);`, [value]);
      }
    });

    it('rejects invalid URLs', async () => {
      for (const value of invalidUrls) {
        let failed = false;
        try {
          await pg.any(`INSERT INTO customers (url) VALUES ($1);`, [value]);
        } catch (e) {
          failed = true;
        }
        expect(failed).toBe(true);
      }
    });
  });

  describe('origin domain (strict regex: ^https?://[^/\\s]+$ - no paths)', () => {
    it('accepts valid origins (protocol + host only)', async () => {
      for (const value of validOrigins) {
        await pg.any(`INSERT INTO customers (origin) VALUES ($1);`, [value]);
      }
    });

    it('rejects origins with paths, query strings, or invalid protocols', async () => {
      for (const value of invalidOrigins) {
        let failed = false;
        try {
          await pg.any(`INSERT INTO customers (origin) VALUES ($1);`, [value]);
        } catch (e) {
          failed = true;
        }
        expect(failed).toBe(true);
      }
    });
  });

  describe('hostname domain (no whitespace: ^[^\\s]+$)', () => {
    it('accepts values without whitespace', async () => {
      const values = [
        'google.com',
        'www.example.com',
        'not-a-hostname',
        'http://with-protocol.com',
        'anything-without-spaces'
      ];
      for (const value of values) {
        await pg.any(`INSERT INTO customers (domain) VALUES ($1);`, [value]);
      }
    });

    it('rejects values with whitespace', async () => {
      const invalidValues = [
        'has spaces',
        'has\ttab',
        'has\nnewline'
      ];
      for (const value of invalidValues) {
        let failed = false;
        try {
          await pg.any(`INSERT INTO customers (domain) VALUES ($1);`, [value]);
        } catch (e) {
          failed = true;
        }
        expect(failed).toBe(true);
      }
    });
  });

  describe('attachment domain (lenient regex: ^https?://[^\\s]+$)', () => {
    it('accepts valid URLs', async () => {
      const values = [
        'http://www.foo.bar/some.jpg',
        'https://foo.bar/some.PNG',
        'https://example.com/path/to/file.pdf'
      ];
      for (const value of values) {
        await pg.any(`INSERT INTO customers (attachment) VALUES ($1);`, [value]);
      }
    });

    it('rejects invalid URLs', async () => {
      const invalidValues = [
        'not-a-url',
        'ftp://wrong-protocol.com/file.pdf',
        'random text with spaces'
      ];
      for (const value of invalidValues) {
        let failed = false;
        try {
          await pg.any(`INSERT INTO customers (attachment) VALUES ($1);`, [value]);
        } catch (e) {
          failed = true;
        }
        expect(failed).toBe(true);
      }
    });
  });

  describe('email domain (must contain @)', () => {
    it('accepts values containing @', async () => {
      const values = [
        'd@google.com',
        'user@example.org',
        'test@localhost',
        'weird@but@valid'
      ];
      for (const value of values) {
        await pg.any(`INSERT INTO customers (email) VALUES ($1);`, [value]);
      }
    });

    it('rejects values without @', async () => {
      const invalidValues = [
        'not-an-email',
        'random text',
        'missing.at.sign'
      ];
      for (const value of invalidValues) {
        let failed = false;
        try {
          await pg.any(`INSERT INTO customers (email) VALUES ($1);`, [value]);
        } catch (e) {
          failed = true;
        }
        expect(failed).toBe(true);
      }
    });
  });

  describe('image domain (jsonb requiring url OR id OR key, optional versions array)', () => {
    it('accepts valid images with url, id, or key', async () => {
      for (const image of validImages) {
        await pg.any(`INSERT INTO customers (image) VALUES ($1::json);`, [image]);
      }
    });

    it('rejects invalid images', async () => {
      for (const image of invalidImages) {
        let failed = false;
        try {
          await pg.any(`INSERT INTO customers (image) VALUES ($1::json);`, [image]);
        } catch (e) {
          failed = true;
        }
        expect(failed).toBe(true);
      }
    });
  });

  describe('upload domain (jsonb requiring url OR id OR key)', () => {
    it('accepts valid uploads with url, id, or key', async () => {
      for (const upload of validUploads) {
        await pg.any(`INSERT INTO customers (upload) VALUES ($1::json);`, [upload]);
      }
    });

    it('rejects uploads without url, id, or key', async () => {
      for (const upload of invalidUploads) {
        let failed = false;
        try {
          await pg.any(`INSERT INTO customers (upload) VALUES ($1::json);`, [upload]);
        } catch (e) {
          failed = true;
        }
        expect(failed).toBe(true);
      }
    });
  });

  describe.each(['upload', 'image'])('%s files-row projection keys', (column) => {
    const insert = (value: unknown) =>
      pg.any(`INSERT INTO customers (${column}) VALUES ($1::json);`, [value]);

    it('accepts the full projection of a files row', async () => {
      await insert({
        id: fileId,
        key: 'e3b0c44298fc1c149afbf4c8996fb924',
        mime: 'image/png',
        bucket_id: bucketId,
        size: 12345,
        filename: 'hero.png'
      });
    });

    it('rejects a bucket_id that is not a uuid', async () => {
      await expect(insert({ id: fileId, bucket_id: 'not-a-uuid' })).rejects.toThrow();
      await expect(insert({ id: fileId, bucket_id: '' })).rejects.toThrow();
      await expect(insert({ id: fileId, bucket_id: `${bucketId}-extra` })).rejects.toThrow();
      await expect(insert({ id: fileId, bucket_id: bucketId.replace(/-/g, '') })).rejects.toThrow();
    });

    it('rejects a bucket_id that is not a json string', async () => {
      await expect(insert({ id: fileId, bucket_id: 12345 })).rejects.toThrow();
      await expect(insert({ id: fileId, bucket_id: { uuid: bucketId } })).rejects.toThrow();
    });

    it('keeps url-only external references valid', async () => {
      await insert({ url: 'https://gravatar.com/avatar/abc', mime: 'image/png' });
    });

    it('leaves the new keys optional', async () => {
      await insert({ id: fileId });
      await insert({ key: 'some-key' });
    });

    it('constrains size to a number and filename to a string', async () => {
      await insert({ id: fileId, size: 0, filename: 'a.txt' });
      await expect(insert({ id: fileId, size: '12345' })).rejects.toThrow();
      await expect(insert({ id: fileId, filename: 42 })).rejects.toThrow();
    });
  });
});
