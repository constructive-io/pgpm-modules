import { getConnections as getC } from 'pgsql-test';

export const getConnections = async () => {
  return getC();
};
