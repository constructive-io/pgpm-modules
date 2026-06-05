-- Deploy schemas/inflection_db/procedures/get_identifier to pg

-- requires: schemas/inflection_db/schema

BEGIN;
-- https://til.hashrocket.com/posts/8f87c65a0a-postgresqls-max-identifier-length-is-63-bytes
CREATE FUNCTION inflection_db.get_identifier(
  str text
) returns text as $$
  select substring(str FROM 1 FOR 63);
$$
LANGUAGE 'sql' STABLE;

COMMIT;
