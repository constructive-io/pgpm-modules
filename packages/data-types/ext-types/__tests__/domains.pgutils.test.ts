import { getConnections } from 'pgsql-test';

const validUrls = [
  'http://foo.com/blah_blah',
  'http://foo.com/blah_blah/',
  'http://foo.com/blah_blah_(wikipedia)',
  'http://foo.com/blah_blah_(wikipedia)_(again)',
  'http://www.example.com/wpstyle/?p=364',
  'https://www.example.com/foo/?bar=baz&inga=42&quux',
  'http://✪df.ws/123',
  'http://foo.com/blah_(wikipedia)#cite-1',
  'http://foo.com/blah_(wikipedia)_blah#cite-1',
  'http://foo.com/(something)?after=parens',
  'http://code.google.com/events/#&product=browser',
  'http://j.mp',
  'http://foo.bar/?q=Test%20URL-encoded%20stuff',
  'http://مثال.إختبار',
  'http://例子.测试',
  'http://उदाहरण.परीक्षा',
  "http://-.~_!$&'()*+,;=:%40:80%2f::::::@example.com",
  'http://1337.net',
  'http://a.b-c.de',
  'https://foo_bar.example.com/'
];

const invalidUrls = [
  'http://##',
  'http://##/',
  'http://foo.bar?q=Spaces should be encoded',
  '//',
  '//a',
  '///a',
  '///',
  'http:///a',
  'foo.com',
  'rdar://1234',
  'h://test',
  'http:// shouldfail.com',
  ':// should fail',
  'http://foo.bar/foo(bar)baz quux',
  'ftps://foo.bar/',
  'http://.www.foo.bar/',
  'http://.www.foo.bar./'
];

const validAttachments = [
  { url: 'http://www.foo.bar/some.jpg', mime: 'image/jpg' },
  { url: 'https://foo.bar/some.PNG', mime: 'image/jpg' }
];

const invalidAttachments = [
  { url: 'hi there' },
  { url: 'https://foo.bar/some.png' }
];

let teardown: (() => Promise<void>) | undefined;
let db: any;
let pg: any;
let d: any;

beforeAll(async () => {
  try {
    ({ db, pg, teardown } = await getConnections());
    const [{ u }] = await db.any('select current_user as u');
    await pg.any(`grant usage, create on schema public to "${u}"`);
    d = db;
  } catch (e) {
  }
});

beforeAll(async () => {
  if (db && typeof db.any === 'function') {
    await db.any(`
CREATE TABLE customers (
  id serial,
  url url,
  image image,
  attachment attachment,
  domain hostname,
  email email
);
  `);
  }
});

beforeEach(async () => {
  if (db && typeof db.beforeEach === 'function') {
    await db.beforeEach();
  }
});

afterEach(async () => {
  if (db && typeof db.afterEach === 'function') {
    await db.afterEach();
  }
});

afterAll(async () => {
  if (typeof teardown === 'function') {
    await teardown();
  }
});

describe('types', () => {
  it('valid attachment and image', async () => {
    for (const value of validAttachments) {
      await db.any(`INSERT INTO customers (image) VALUES ($1::json);`, [value]);
      await db.any(`INSERT INTO customers (attachment) VALUES ($1::json);`, [value]);
    }
  });

  it('invalid attachment and image', async () => {
    for (const value of invalidAttachments) {
      let failed = false;
      try {
        await db.any(`INSERT INTO customers (attachment) VALUES ($1);`, [value]);
      } catch (e) {
        failed = true;
      }
      expect(failed).toBe(true);
      failed = false;
      try {
        await db.any(`INSERT INTO customers (image) VALUES ($1);`, [value]);
      } catch (e) {
        failed = true;
      }
      expect(failed).toBe(true);
    }
  });

  it('valid url', async () => {
    for (const value of validUrls) {
      await db.any(`INSERT INTO customers (url) VALUES ($1);`, [value]);
    }
  });

  it('invalid url', async () => {
    for (const value of invalidUrls) {
      let failed = false;
      try {
        await db.any(`INSERT INTO customers (url) VALUES ($1);`, [value]);
      } catch (e) {
        failed = true;
      }
      expect(failed).toBe(true);
    }
  });

  it('email', async () => {
    await db.any(`
    INSERT INTO customers (email) VALUES
    ('d@google.com'),
    ('d@google.in'),
    ('d@google.in'),
    ('d@www.google.in'),
    ('d@google.io'),
    ('dan@google.some.other.com')`);
  });

  it('not email', async () => {
    let failed = false;
    try {
      await db.any(`
      INSERT INTO customers (email) VALUES
      ('http://google.some.other.com')`);
    } catch (e) {
      failed = true;
    }
    expect(failed).toBe(true);
  });

  it('hostname', async () => {
    await db.any(`
    INSERT INTO customers (domain) VALUES
    ('google.com'),
    ('google.in'),
    ('google.in'),
    ('www.google.in'),
    ('google.io'),
    ('google.some.other.com')`);
  });

  it('not hostname', async () => {
    let failed = false;
    try {
      await db.any(`
      INSERT INTO customers (domain) VALUES
      ('http://google.some.other.com')`);
    } catch (e) {
      failed = true;
    }
    expect(failed).toBe(true);
  });

  it('not hostname 2', async () => {
    let failed = false;
    try {
      await db.any(`
      INSERT INTO customers (domain) VALUES
      ('google.some.other.com/a/b/d')`);
    } catch (e) {
      failed = true;
    }
    expect(failed).toBe(true);
  });
});
