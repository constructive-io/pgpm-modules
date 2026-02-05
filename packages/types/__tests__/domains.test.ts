import { getConnections, PgTestClient } from 'pgsql-test';

// Validation rules:
// - url: lenient regex ^https?://[^\s]+$ (must start with http/https, no whitespace, paths allowed)
// - origin: strict regex ^https?://[^/\s]+$ (protocol + host only, no paths for CORS security)
// - hostname, attachment, email: no validation (plain text)
// - image: jsonb requiring 'url' key
// - upload: jsonb requiring 'url' OR 'id' OR 'key'

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
  { url: 'any-string-is-fine' }
];

const invalidImages = [
  { notUrl: 'missing url key' },
  { id: 'has id but not url' }
];

const validUploads = [
  { url: 'http://www.foo.bar/some.jpg' },
  { url: 'https://foo.bar/some.PNG' },
  { id: 'some-id' },
  { key: 'some-key' },
  { url: 'any-string', id: 'with-id' }
];

const invalidUploads = [
  { notUrl: 'missing required keys' },
  { mime: 'only mime, no url/id/key' }
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

  describe('hostname domain (plain text, no validation)', () => {
    it('accepts any text value', async () => {
      const values = [
        'google.com',
        'www.example.com',
        'not-a-hostname',
        'http://with-protocol.com'
      ];
      for (const value of values) {
        await pg.any(`INSERT INTO customers (domain) VALUES ($1);`, [value]);
      }
    });
  });

  describe('attachment domain (plain text, no validation)', () => {
    it('accepts any text value', async () => {
      const values = [
        'http://www.foo.bar/some.jpg',
        'https://foo.bar/some.PNG',
        'not-a-url',
        'random text'
      ];
      for (const value of values) {
        await pg.any(`INSERT INTO customers (attachment) VALUES ($1);`, [value]);
      }
    });
  });

  describe('email domain (citext, no validation)', () => {
    it('accepts any text value', async () => {
      await pg.any(`
      INSERT INTO customers (email) VALUES
      ('d@google.com'),
      ('not-an-email'),
      ('random text')`);
    });
  });

  describe('image domain (jsonb requiring url key)', () => {
    it('accepts valid images with url key', async () => {
      for (const image of validImages) {
        await pg.any(`INSERT INTO customers (image) VALUES ($1::json);`, [image]);
      }
    });

    it('rejects images without url key', async () => {
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
});
