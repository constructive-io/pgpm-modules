-- Deploy schemas/inflection_db/procedures/get_unique_index_name to pg
-- requires: schemas/inflection_db/schema
-- requires: schemas/inflection_db/procedures/get_table_name
-- requires: schemas/inflection_db/procedures/get_identifier

BEGIN;
CREATE FUNCTION inflection_db.get_unique_index_name (table_name text, fields text[])
  RETURNS text
  AS $$
  SELECT
    inflection_db.get_identifier (
      inflection.underscore (
        array_to_string(ARRAY[inflection_db.get_table_name (table_name)] || fields || ARRAY['key'], '_'))
    );
$$
LANGUAGE 'sql'
STABLE;
COMMIT;
