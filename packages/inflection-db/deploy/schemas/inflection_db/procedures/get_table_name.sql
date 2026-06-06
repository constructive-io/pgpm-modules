-- Deploy schemas/inflection_db/procedures/get_table_name to pg
-- requires: schemas/inflection_db/schema
-- requires: schemas/inflection_db/procedures/get_identifier

BEGIN;
CREATE FUNCTION inflection_db.get_table_name (table_name text)
  RETURNS text
  AS $$
  SELECT
    inflection_db.get_identifier (inflection.plural (inflection.underscore (table_name)));
$$
LANGUAGE 'sql'
IMMUTABLE;

CREATE FUNCTION inflection_db.get_table_name (parts text[])
  RETURNS text
  AS $$
  SELECT
    inflection_db.get_identifier (inflection.plural (inflection.underscore (parts)));
$$
LANGUAGE 'sql'
IMMUTABLE;

COMMIT;

