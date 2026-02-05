import { getConnections, PgTestClient } from 'pgsql-test';

// With simplified validation, all text values are valid for url, hostname, attachment, email
// Only structural checks remain: image requires 'url' key, upload requires 'url' OR 'id' OR 'key'

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
  describe('url domain (plain text, no validation)', () => {
    it('accepts any text value', async () => {
      const values = [
        'http://foo.com/blah',
        'https://example.com',
        'not-a-url',
        'ftp://something',
        'random text'
      ];
      for (const value of values) {
        await pg.any(`INSERT INTO customers (url) VALUES ($1);`, [value]);
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
