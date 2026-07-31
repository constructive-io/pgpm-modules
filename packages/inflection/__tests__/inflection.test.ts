import cases from 'jest-in-case';
import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

describe('inflection', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
  });

  afterAll(async () => {
    await teardown();
  });

  cases(
    'slugify',
    async (opts: { name: string; allowUnicode: boolean; result: string }) => {
      const { pg_slugify } = await pg.one(
        'SELECT * FROM inflection.pg_slugify($1, $2)',
        [opts.name, opts.allowUnicode]
      );
      expect(pg_slugify).toEqual(opts.result);
    },
    [
      { name: 'Hello, World!', allowUnicode: false, result: 'Hello_World' },
      { name: 'Héllø, Wørld!', allowUnicode: false, result: 'Hello_World' },
      { name: 'spam & eggs', allowUnicode: false, result: 'spam_eggs' },
      { name: 'spam & ıçüş', allowUnicode: true, result: 'spam_ıçüş' },
      { name: 'foo ıç bar', allowUnicode: true, result: 'foo_ıç_bar' },
      { name: '    foo ıç bar', allowUnicode: true, result: 'foo_ıç_bar' },
      { name: '你好', allowUnicode: true, result: '你好' },
      { name: 'message_properties', allowUnicode: false, result: 'message_properties' },
      { name: 'MessageProperties', allowUnicode: false, result: 'MessageProperties' },
      { name: 'WebACL', allowUnicode: false, result: 'WebAcl' }
    ]
  );

  cases(
    'underscore',
    async (opts: { name: string; result: string }) => {
      const { underscore } = await pg.one(
        'SELECT * FROM inflection.underscore($1)',
        [opts.name]
      );
      expect(underscore).toEqual(opts.result);
    },
    [
      { name: 'MessageProperties', result: 'message_properties' },
      { name: 'messageProperties', result: 'message_properties' },
      { name: 'message_properties', result: 'message_properties' },
      { name: 'User Post', result: 'user_post' },
      { name: 'MP', result: 'mp' },
      { name: 'WebACL', result: 'web_acl' },
      { name: 'wabCdEfgh', result: 'wab_cd_efgh' },
      { name: 'WabCDEfgH', result: 'wab_cd_efgh' }
    ]
  );

  cases(
    'no_single_underscores',
    async (opts: { name: string; result: string }) => {
      const { no_single_underscores } = await pg.one(
        'SELECT * FROM inflection.no_single_underscores($1)',
        [opts.name]
      );
      expect(no_single_underscores).toEqual(opts.result);
    },
    [
      { name: 'w_a_b_cd_efg_h', result: 'wab_cd_efgh' }
    ]
  );

  cases(
    'pascal',
    async (opts: { name: string; result: string }) => {
      const { pascal } = await pg.one(
        'SELECT * FROM inflection.pascal($1)',
        [opts.name]
      );
      expect(pascal).toEqual(opts.result);
    },
    [
      { name: 'MessageProperties', result: 'MessageProperties' },
      { name: 'message_properties', result: 'MessageProperties' },
      { name: 'messageProperties', result: 'MessageProperties' },
      { name: 'MP', result: 'Mp' },
      { name: 'WebAcl', result: 'WebAcl' },
      { name: 'WebACL', result: 'WebAcl' },
      { name: 'web_acl', result: 'WebAcl' },
      { name: 'web acl', result: 'WebAcl' },
      { name: 'Web Acl', result: 'WebAcl' },
      { name: 'Web ACL', result: 'WebAcl' },
      { name: 'w_a_b', result: 'Wab' }
    ]
  );

  cases(
    'camel',
    async (opts: { name: string; result: string }) => {
      const { camel } = await pg.one(
        'SELECT * FROM inflection.camel($1)',
        [opts.name]
      );
      expect(camel).toEqual(opts.result);
    },
    [
      { name: 'MessageProperties', result: 'messageProperties' },
      { name: 'message_properties', result: 'messageProperties' },
      { name: 'messageProperties', result: 'messageProperties' },
      { name: 'MP', result: 'mp' },
      { name: 'webAcl', result: 'webAcl' },
      { name: 'WebACL', result: 'webAcl' },
      { name: 'web_acl', result: 'webAcl' },
      { name: 'web acl', result: 'webAcl' },
      { name: 'Web Acl', result: 'webAcl' },
      { name: 'Web ACL', result: 'webAcl' },
      { name: 'w_a_b', result: 'wab' },
      { name: 'w_a_b_cd_efg_h', result: 'wabCdEfgh' }
    ]
  );

  cases(
    'no_consecutive_caps',
    async (opts: { name: string; result: string }) => {
      const { no_consecutive_caps } = await pg.one(
        'SELECT * FROM inflection.no_consecutive_caps($1)',
        [opts.name]
      );
      expect(no_consecutive_caps).toEqual(opts.result);
    },
    [
      { name: 'MP', result: 'Mp' },
      { name: 'Web_ACL', result: 'Web_Acl' },
      { name: 'MPComplete', result: 'MpComplete' },
      { name: 'ACLWindow', result: 'AclWindow' }
    ]
  );

  cases(
    'plural',
    async (opts: { name: string; result: string }) => {
      const { plural } = await pg.one(
        'SELECT * FROM inflection.plural($1)',
        [opts.name]
      );
      expect(plural).toEqual(opts.result);
    },
    [
      { name: 'user_login', result: 'user_logins' },
      { name: 'user Login', result: 'user Logins' },
      { name: 'user_logins', result: 'user_logins' },
      { name: 'user Logins', result: 'user Logins' },
      { name: 'children', result: 'children' },
      { name: 'child', result: 'children' },
      { name: 'man', result: 'men' },
      { name: 'men', result: 'men' },
      // node.inflection v3 sync: octopus/virus use -uses
      { name: 'octopus', result: 'octopuses' },
      { name: 'virus', result: 'viruses' },
      { name: 'octopuses', result: 'octopuses' },
      { name: 'viruses', result: 'viruses' },
      // node.inflection v3 sync: drive, focus, bonus, database
      { name: 'drive', result: 'drives' },
      { name: 'drives', result: 'drives' },
      { name: 'focus', result: 'focuses' },
      { name: 'bonus', result: 'bonuses' },
      { name: 'database', result: 'databases' },
      { name: 'databases', result: 'databases' },
      // uncountable words
      { name: 'sheep', result: 'sheep' },
      { name: 'equipment', result: 'equipment' },
      { name: 'information', result: 'information' },
      { name: 'deer', result: 'deer' },
      { name: 'series', result: 'series' },
      { name: 'species', result: 'species' },
      // -f/-fe: only the f-stem nouns take -ves
      { name: 'knife', result: 'knives' },
      { name: 'wolf', result: 'wolves' },
      { name: 'leaf', result: 'leaves' },
      { name: 'thief', result: 'thieves' },
      { name: 'shelf', result: 'shelves' },
      { name: 'cafe', result: 'cafes' },
      { name: 'safe', result: 'safes' },
      { name: 'roof', result: 'roofs' },
      { name: 'belief', result: 'beliefs' },
      { name: 'derive', result: 'derives' },
      { name: 'mouse', result: 'mice' },
      { name: 'spouse', result: 'spouses' },
      { name: 'apis', result: 'apis' }
    ]
  );

  cases(
    'singular',
    async (opts: { name: string; result: string }) => {
      const { singular } = await pg.one(
        'SELECT * FROM inflection.singular($1)',
        [opts.name]
      );
      expect(singular).toEqual(opts.result);
    },
    [
      { name: 'user_logins', result: 'user_login' },
      { name: 'user Logins', result: 'user Login' },
      { name: 'user_login', result: 'user_login' },
      { name: 'user Login', result: 'user Login' },
      { name: 'children', result: 'child' },
      { name: 'child', result: 'child' },
      { name: 'man', result: 'man' },
      { name: 'men', result: 'man' },
      // node.inflection v3 sync: octopus/virus use -uses
      { name: 'octopuses', result: 'octopus' },
      { name: 'viruses', result: 'virus' },
      { name: 'octopus', result: 'octopus' },
      { name: 'virus', result: 'virus' },
      // node.inflection v3 sync: drive, database
      { name: 'drives', result: 'drive' },
      { name: 'drive', result: 'drive' },
      { name: 'databases', result: 'database' },
      { name: 'database', result: 'database' },
      { name: 'bonuses', result: 'bonus' },
      // Latin suffix overrides (PostGraphile-compatible)
      { name: 'schemata', result: 'schema' },
      { name: 'phenomena', result: 'phenomenon' },
      { name: 'memoranda', result: 'memorandum' },
      { name: 'curricula', result: 'curriculum' },
      { name: 'criteria', result: 'criterion' },
      { name: 'media', result: 'medium' },
      { name: 'data', result: 'datum' },
      { name: 'strata', result: 'stratum' },
      // -ves: only the f-stem nouns rewrite to -f/-fe; the rest drop the "s".
      // The old ([^fo])ves$ -> \1fe rule turned "derives" into "derife".
      { name: 'derives', result: 'derive' },
      { name: 'metaschema_public.derives', result: 'metaschema_public.derive' },
      { name: 'archives', result: 'archive' },
      { name: 'curves', result: 'curve' },
      { name: 'olives', result: 'olive' },
      { name: 'solves', result: 'solve' },
      { name: 'valves', result: 'valve' },
      { name: 'motives', result: 'motive' },
      { name: 'natives', result: 'native' },
      { name: 'hives', result: 'hive' },
      { name: 'knives', result: 'knife' },
      { name: 'lives', result: 'life' },
      { name: 'wives', result: 'wife' },
      { name: 'wolves', result: 'wolf' },
      { name: 'shelves', result: 'shelf' },
      { name: 'halves', result: 'half' },
      { name: 'leaves', result: 'leaf' },
      { name: 'loaves', result: 'loaf' },
      { name: 'thieves', result: 'thief' },
      { name: 'hooves', result: 'hoof' },
      // -ice: only mice/lice are plurals
      { name: 'mice', result: 'mouse' },
      { name: 'lice', result: 'louse' },
      { name: 'police', result: 'police' },
      { name: 'service', result: 'service' },
      { name: 'chalice', result: 'chalice' },
      // -is/-us words are already singular
      { name: 'iris', result: 'iris' },
      { name: 'apis', result: 'api' },
      { name: 'analysis', result: 'analysis' },
      { name: 'analyses', result: 'analysis' },
      { name: 'status', result: 'status' },
      // uncountable words
      { name: 'sheep', result: 'sheep' },
      { name: 'equipment', result: 'equipment' },
      { name: 'information', result: 'information' }
    ]
  );

  cases(
    'dns_1123',
    async (opts: { name: string; result: string }) => {
      const { dns_1123 } = await pg.one(
        'SELECT * FROM inflection.dns_1123($1)',
        [opts.name]
      );
      expect(dns_1123).toEqual(opts.result);
    },
    [
      { name: 'api', result: 'api' },
      { name: 'MyService', result: 'myservice' },
      { name: 'my_service', result: 'my-service' },
      { name: 'org:api', result: 'org--api' },
      { name: 'Hello, World!', result: 'helloworld' },
      { name: '__leading', result: 'leading' },
      { name: 'trailing__', result: 'trailing' },
      { name: '---', result: '' },
      {
        name: 'a'.repeat(80),
        result: 'a'.repeat(63)
      },
      {
        // truncation lands on a '-'; trailing non-alphanumerics are dropped
        name: `${'a'.repeat(62)}-bcd`,
        result: 'a'.repeat(62)
      }
    ]
  );
});
