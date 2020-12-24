jasmine.DEFAULT_TIMEOUT_INTERVAL = 30000;

import { getConnections as get } from '@launchql/graphql-testing';

export const getConnections = async (schemas) =>
  get({
    authRole: 'administrator',
    schemas
  });
