import { getConnections } from './utils/graphql';
import gql from 'graphql-tag';

let teardown: (() => Promise<void>) | undefined, query: any;

beforeAll(async () => {
  try {
    ({ teardown, query } = await getConnections(['measurements']));
  } catch (e) {
  }
});

afterAll(async () => {
  if (typeof teardown === 'function') {
    await teardown();
  }
});

const SimpleQuery = gql`
  query {
    __typename
  }
`;

describe('signup', () => {
  describe('has an API', () => {
    it('query your API', async () => {
      const result = await query(SimpleQuery, {}, true);
      expect(result.errors).toBeFalsy();
    });
  });
});
