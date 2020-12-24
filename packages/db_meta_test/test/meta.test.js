import { getConnections } from './utils/graphql';
import { ApiQuery, SiteQuery } from './utils/gql';
import { snap } from './utils/snaps';

let teardown, graphQLQuery;

beforeAll(async () => {
  ({ teardown, graphQLQuery } = await getConnections([
    'collections_public',
    'meta_public'
  ]));
});

afterAll(async () => {
  try {
    await teardown();
  } catch (e) {
    console.log(e);
  }
});

it('api', async () => {
  const result = await graphQLQuery(
    ApiQuery,
    {
      subdomain: 'api',
      domain: 'lql.io'
    },
    true
  );
  snap(result.data);
});

it('meta', async () => {
  const result = await graphQLQuery(
    ApiQuery,
    {
      subdomain: 'meta',
      domain: 'lql.io'
    },
    true
  );
  snap(result.data);
});

it('site', async () => {
  const result = await graphQLQuery(
    SiteQuery,
    {
      subdomain: 'app',
      domain: 'lql.io'
    },
    true
  );
  snap(result.data);
});
