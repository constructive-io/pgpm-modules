-- Deploy schemas/inflection_db/procedures/get_namespace_name to pg
-- requires: schemas/inflection_db/schema
-- requires: schemas/inflection_db/procedures/get_identifier

BEGIN;

CREATE FUNCTION inflection_db.get_namespace_name (parts text[])
  RETURNS text
  AS $$
  SELECT
    inflection_db.get_identifier (inflection.underscore (parts));
$$
LANGUAGE 'sql'
IMMUTABLE;

COMMIT;
