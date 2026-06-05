-- Deploy schemas/inflection_db/procedures/get_field_name to pg
-- requires: schemas/inflection_db/schema
-- requires: schemas/inflection_db/procedures/get_identifier

BEGIN;
CREATE FUNCTION inflection_db.get_field_name (field_name text)
  RETURNS text
  AS $$
  SELECT
    inflection_db.get_identifier (inflection.underscore (field_name));
$$
LANGUAGE 'sql'
IMMUTABLE;

CREATE FUNCTION inflection_db.get_field_name (parts text[])
  RETURNS text
  AS $$
  SELECT
    inflection_db.get_identifier (inflection.underscore (parts));
$$
LANGUAGE 'sql'
IMMUTABLE;
COMMIT;
